//
//  JitsiMeetViewController.swift
//  JitsiSample
//
//  Created by Imran Sayeed on 29/7/21.
//

import UIKit
import AVFoundation
import JitsiMeetSDK
import CallKit

class JitsiMeetViewController: UIViewController {
    private let roomName = "SampleJitsiAppRoom101"
    private var jitsiMeetView: JitsiMeetView?
    private var pipViewCoordinator: PiPViewCoordinator?
    private var numberOfOtherParticipantsInCall = 0
    private var timer: Timer?
    private var isTimeLabelAlreadyAdded = false
    
    var player: AVAudioPlayer?
    private var initialTime: Date?
    var callManager: CallManager?
    var call: Call?
    var callUUID: UUID?
    
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
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        joinMeet()
    }
    
    @objc private func didReceiveAudioMutedOption(_ notification: NSNotification) {
        guard let muted = notification.userInfo?[Constants.callMuted] as? Bool else {
            return
        }
        jitsiMeetView?.setAudioMuted(muted)
    }
    
    private func joinMeet() {
        guard let call = call else {
            return
        }
        let jitsiMeetView = JitsiMeetView()
        jitsiMeetView.delegate = self
        self.jitsiMeetView = jitsiMeetView
        view.backgroundColor = .red
        
        // display and subject is different because of callkit will show subject after receiving any call and display name will show avatar like this Imran -> I
        let displayName = call.outgoing ? Constants.jitsiOutgoingParticipantName : Constants.jitsiIncomingParticipantName
        
        let subject = call.outgoing ? Constants.jitsiIncomingParticipantName : Constants.jitsiOutgoingParticipantName
        
        
        let options = JitsiMeetConferenceOptions
            .fromBuilder {[unowned self] (builder) in
                builder.callUUID = call.uuid
                builder.callHandle = "Dummy SSF App"
                builder.videoMuted = call.isAudioCall
                builder.room = self.roomName
                builder.subject = subject
                let userInfo = JitsiMeetUserInfo()
                userInfo.displayName = displayName
                builder.userInfo = userInfo
            }
        
        jitsiMeetView.join(options)
        pipViewCoordinator = PiPViewCoordinator(withView: jitsiMeetView)
        pipViewCoordinator?.configureAsStickyView(withParentView: view)
        pipViewCoordinator?.initialPositionInSuperview = .lowerRightCorner
        jitsiMeetView.alpha = 1
        pipViewCoordinator?.show()
    }
    
    private func endCallManually(withEndCallReason reason: CXCallEndedReason = .remoteEnded) {
        self.hideCallingLabelStopRiningSound()
        jitsiMeetView?.hangUp()
        guard let call = call, let getCall = callManager?.callWithUUID(uuid: call.uuid)  else {
            return
        }
        callManager?.end(call: getCall)
        cleanUp()
    }
    
    private func hideCallingLabelStopRiningSound() {
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
        jitsiMeetView = nil
        pipViewCoordinator = nil
    }
    
}

extension JitsiMeetViewController: JitsiMeetViewDelegate {
    func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        DispatchQueue.main.async {[weak self] in
            self?.endCallManually()
        }
    }
    
    func conferenceJoined(_ data: [AnyHashable : Any]!) {
        if let isOutgoing = call?.outgoing, isOutgoing  {
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
        if let isOutgoing = call?.outgoing, !isOutgoing {
            self.hideCallingLabelStopRiningSound()
        }
    }
    
    func participantLeft(_ data: [AnyHashable : Any]!) {
        self.numberOfOtherParticipantsInCall -= 1
        
        if numberOfOtherParticipantsInCall == 0 {
            endCallManually()
        }
    }
    
    func enterPicture(inPicture data: [AnyHashable : Any]!) {
        DispatchQueue.main.async {
            self.pipViewCoordinator?.enterPictureInPicture()
        }
    }
}

extension JitsiMeetViewController {
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
