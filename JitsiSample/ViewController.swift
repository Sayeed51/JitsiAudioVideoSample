//
//  ViewController.swift
//  JitsiSample
//
//  Created by Phaninder Kumar on 20/10/20.
//

import UIKit
import JitsiMeetSDK
import AVFoundation
import SnapKit
import UserNotifications

class ViewController: UIViewController {
    @IBOutlet weak var reportIncomingCallButton: UIButton!
    @IBOutlet weak var initiateOutgoingCallButton: UIButton!
    fileprivate var jitsiMeetView: JitsiMeetView?
    fileprivate var pipViewCoordinator: PiPViewCoordinator?
    @IBOutlet weak var callButtonsStackView: UIStackView!
    
    private var isAudioMuted = false
    private var avatarName = "something"
    private var isAudioCall = true
    private var numberOfOtherParticipantsInCall = 0
    private var isOutgoingCall = false
    private var timer: Timer?
    private var isTimeLabelAlreadyAdded = false
    
    var player: AVAudioPlayer?
    private var initialTime: Date?
    private let roomName = "SampleJitsiAppRoom101"
    var callManager: CallManager?
    var call: Call?
    
    private lazy var callingLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .yellow
        label.font = .systemFont(ofSize: 12)
        label.text = "CALLING...."
        label.backgroundColor = .clear
        label.textAlignment = .center
        
        return label
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .yellow
        label.font = .systemFont(ofSize: 12)
        label.text = "00:00"
        label.backgroundColor = .clear
        label.textAlignment = .center
        
        return label
    }()
    
    deinit {
        cleanUp()
        //JMCallKitProxy.removeListener(self)
        JMCallKitProxy.callKitProvider?.invalidate()
    }
    
    func playSound() {
        guard let url = Bundle.main.url(forResource: "ringbackTone", withExtension: "wav") else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat)
            try AVAudioSession.sharedInstance().setActive(true)
            /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            /* iOS 10 and earlier require the following line:
             player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
            guard let player = player else { return }
            player.play()
        } catch let error {
            debugPrint(error.localizedDescription)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func reportIncomingCallButtonTapped(_ sender: UIButton) {
        isOutgoingCall = false
        startIncomingCall()
    }
    
    @IBAction func initiateOutgoingCallButtonTapped(_ sender: UIButton) {
        isOutgoingCall = true
        startOutgoingCall()
    }
    
    func joinMeet() {
        cleanUp()
        guard let call = call else { return  }
        callButtonsStackView.isHidden = true
        isAudioCall = call.isAudioCall
        isOutgoingCall = call.outgoing
        avatarName = isOutgoingCall ? Constants.jitsiOutgoingParticipantName: Constants.jitsiIncomingParticipantName
        let jitsiMeetView = JitsiMeetView()
        jitsiMeetView.delegate = self
        self.jitsiMeetView = jitsiMeetView
        
        let options = JitsiMeetConferenceOptions
            .fromBuilder {[unowned self] (builder) in
                builder.callUUID = call.uuid
                builder.callHandle = "Dummy SSF App"
                builder.videoMuted = isAudioCall
                builder.room = self.roomName
                builder.subject = self.avatarName
                let userInfo = JitsiMeetUserInfo()
                userInfo.displayName = self.avatarName
                builder.userInfo = userInfo
            }
        
        jitsiMeetView.join(options)
        pipViewCoordinator = PiPViewCoordinator(withView: jitsiMeetView)
        pipViewCoordinator?.configureAsStickyView(withParentView: view)
        pipViewCoordinator?.initialPositionInSuperview = .lowerRightCorner
        jitsiMeetView.alpha = 1
        pipViewCoordinator?.show()
    }
    
    private func endCallManually() {
        self.hideCallingLabelStopRiningSound()
        //JMCallKitProxy.reportCall(with: localCallUUID ?? UUID(), endedAt: nil, reason: reason)
        guard let call = call else { return  }
        callManager?.end(call: call)
        jitsiMeetView?.hangUp()
        
        self.callButtonsStackView.isHidden = false
        cleanUp()
    }
    
    private func hideCallingLabelStopRiningSound() {
        if !isOutgoingCall {
            return
        }
        self.callingLabel.isHidden = true
        
        player?.stop()
        player = nil
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
    }
    
    private func addCallingLabel() {
        self.jitsiMeetView?.addSubview(self.callingLabel)
        callingLabel.isHidden = false
        self.callingLabel.snp.makeConstraints {  (make) in
            make.topMargin.lessThanOrEqualToSuperview().offset(100)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(50)
        }
        playSound()
    }
    
    func addTimeLabel() {
        if isTimeLabelAlreadyAdded {
            return
        }
        self.jitsiMeetView?.addSubview(self.timeLabel)
        isTimeLabelAlreadyAdded = true
        self.timeLabel.snp.makeConstraints {  (make) in
            make.topMargin.lessThanOrEqualToSuperview().offset(50)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(50)
        }
        
        timeLabel.isHidden = true
    }
    
    private func cleanUp() {
        jitsiMeetView?.removeFromSuperview()
        numberOfOtherParticipantsInCall = 0
        timer?.invalidate()
        timer = nil
        initialTime = nil
        timeLabel.text = nil
        isTimeLabelAlreadyAdded = false
        isAudioMuted = false
        isAudioCall = true
        jitsiMeetView = nil
        pipViewCoordinator = nil
    }
}

// MARK:- Incoming/outgoing call implementation methods

extension ViewController {
    private func startIncomingCall() {
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return  }
        let backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        let localUUID = UUID()
        appDelegate.providerDelegate.reportIncomingCall(uuid: localUUID, handle: Constants.jitsiTitle, displayName: Constants.jitsiOutgoingParticipantName, completion: { error in
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        })
    }
    
    private func startOutgoingCall() {
        guard let appdelegate = UIApplication.shared.delegate as? AppDelegate else { return  }
        appdelegate.callManager.startCall(handle: Constants.jitsiIncomingParticipantName, videoEnabled: isAudioCall)
    }
}


extension ViewController: JitsiMeetViewDelegate {
    func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        DispatchQueue.main.async {
            self.pipViewCoordinator?.hide() { _ in
                self.endCallManually()
            }
        }
    }
    
    func conferenceJoined(_ data: [AnyHashable : Any]!) {
        if isOutgoingCall {
            self.addCallingLabel()
        }
        addTimeLabel()
    }
    
    func participantJoined(_ data: [AnyHashable : Any]!) {
        guard let isLocalUser = data["isLocal"] as? Bool else {
            self.hideCallingLabelStopRiningSound()
            addTimeLabel()
            self.timeLabel.isHidden = false
            startTimer()
            
            return
        }
        self.numberOfOtherParticipantsInCall += 1
        if !isLocalUser {
            self.hideCallingLabelStopRiningSound()
        }
    }
    
    func participantLeft(_ data: [AnyHashable : Any]!) {
        self.numberOfOtherParticipantsInCall -= 1
        
        if numberOfOtherParticipantsInCall == 0 {
            self.jitsiMeetView?.hangUp()
        }
    }
    
    func enterPicture(inPicture data: [AnyHashable : Any]!) {
        DispatchQueue.main.async {
            self.pipViewCoordinator?.enterPictureInPicture()
        }
    }
}

extension ViewController {
    @objc private func updateTime() {
        initialTime = initialTime ?? Date()
        let time = Date().timeIntervalSince(initialTime!)
        
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        
        var times: [String] = []
        if hours > 0 {
            let hoursStr = hours > 9 ? "\(hours)" : ("0"+"\(hours)")
            times.append(hoursStr)
        }
        if minutes > 0 {
            let minutesStr = minutes > 9 ? "\(minutes)" : ("0"+"\(minutes)")
            times.append(minutesStr)
        } else {
            times.append("00")
        }
        let secondsStr = seconds > 9 ? "\(seconds)" : ("0" + "\(seconds)")
        times.append(secondsStr)
        
        timeLabel.text = times.joined(separator: ":")
    }
}
