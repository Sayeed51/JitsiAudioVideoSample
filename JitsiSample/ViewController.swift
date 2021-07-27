//
//  ViewController.swift
//  JitsiSample
//
//  Created by Phaninder Kumar on 20/10/20.
//

import UIKit
import JitsiMeetSDK
import AVFoundation
import CallKit
import WebRTC
import SnapKit
import PushKit
import UserNotifications

struct Constants {
    static let incomingCall = "incomingCall"
    static  let jitsiTitle = "SSF APP"
    static let jitsiOutgoingParticipantName = "Imran Sayeed"
    static let jitsiIncomingParticipantName = "Emroj Hossain"
    static let callUUID = "callUUID"
}

class ViewController: UIViewController {
    @IBOutlet weak var reportIncomingCallButton: UIButton!
    @IBOutlet weak var initiateOutgoingCallButton: UIButton!
    fileprivate var jitsiMeetView: JitsiMeetView?
    fileprivate var pipViewCoordinator: PiPViewCoordinator?
    @IBOutlet weak var callButtonsStackView: UIStackView!
    
     var localCallUUID: UUID?
    private var isAudioMuted = false
     var avatarName = "something"
    private var isAudioCall = true
    private var numberOfOtherParticipantsInCall = 0
     var isOutgoingCall = false
    private var timer: Timer?
    private var isTimeLabelAlreadyAdded = false
    
    var player: AVAudioPlayer?
    private var initialTime: Date?
//     let jitsiTitle = "SSF APP"
//     let jitsiOutgoingParticipantName = "Imran Sayeed"
//     let jitsiIncomingParticipantName = "Emroj Hossain"
    private let roomName = "SampleJitsiAppRoom101"
    
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
        JMCallKitProxy.removeListener(self)
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
        
        JMCallKitProxy.addListener(self)
        
//        let registry = PKPushRegistry(queue: nil)
//        registry.delegate = self
//        registry.desiredPushTypes = [PKPushType.voIP]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveIncomingCall(_:)), name: Notification.Name(rawValue: Constants.incomingCall), object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func didReceiveIncomingCall(_ notification: NSNotification) {
        guard let uuid = notification.userInfo?[Constants.callUUID] as? UUID else {
            return
        }
        localCallUUID = uuid
        JMCallKitProxy.configureProvider(localizedName: Constants.jitsiTitle, ringtoneSound: nil, iconTemplateImageData: nil)
        
        print(" startIncomingCall function-->Incoming Call UUID: \(localCallUUID!.uuidString)")
        avatarName = Constants.jitsiIncomingParticipantName
        self.callButtonsStackView.isHidden = true
    }
    
    @IBAction func reportIncomingCallButtonTapped(_ sender: UIButton) {
        isOutgoingCall = false
        startIncomingCall()
    }
    
    @IBAction func initiateOutgoingCallButtonTapped(_ sender: UIButton) {
        isOutgoingCall = true
        startOutgoingCall()
    }
    
    private func joinMeet(callID: UUID) {
        cleanUp()
        let jitsiMeetView = JitsiMeetView()
        jitsiMeetView.delegate = self
        self.jitsiMeetView = jitsiMeetView
        
        let options = JitsiMeetConferenceOptions
            .fromBuilder {[unowned self] (builder) in
                builder.callUUID = callID
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
    
    private func endCallManually(withEndCallReason reason: CXCallEndedReason = .remoteEnded) {
        self.hideCallingLabelStopRiningSound()
        JMCallKitProxy.reportCall(with: localCallUUID ?? UUID(), endedAt: nil, reason: reason)
        jitsiMeetView?.hangUp()
        
        self.callButtonsStackView.isHidden = false
        localCallUUID = nil
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
        
        localCallUUID = UUID()
        JMCallKitProxy.configureProvider(localizedName: Constants.jitsiTitle, ringtoneSound: nil, iconTemplateImageData: nil)
        
        print(" startIncomingCall function-->Incoming Call UUID: \(localCallUUID!.uuidString)")
        avatarName = Constants.jitsiIncomingParticipantName
        
        let backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        DispatchQueue.main.asyncAfter(
            deadline: .now()+3,
            execute: { [unowned self] in
                JMCallKitProxy.reportNewIncomingCall(
                    UUID: localCallUUID!,
                    handle: Constants.jitsiTitle,
                    displayName: Constants.jitsiOutgoingParticipantName,
                    hasVideo: false
                )  {  [unowned self] (error) in
                    guard error == nil else {
                        print("Failed, error: \(String(describing: error))")
                        self.callButtonsStackView.isHidden = false
                        return
                    }
                    print("Successfully reported")
                    self.callButtonsStackView.isHidden = true
                    UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                }
            }
        )
    }
    
    private func startOutgoingCall() {
        callButtonsStackView.isHidden = true
        localCallUUID = UUID()
        avatarName = Constants.jitsiOutgoingParticipantName
        print("reporting outgoing call from button tapped and UUID--> \(localCallUUID?.uuidString)")
        let handle = CXHandle(type: .generic, value: Constants.jitsiIncomingParticipantName)
        // 2
        let startCallAction = CXStartCallAction(call: localCallUUID!, handle: handle)
        // 3
        startCallAction.isVideo = isAudioCall
        let transaction = CXTransaction(action: startCallAction)
        //JMCallKitProxy.reportOutgoingCall(with: localCallUUID ?? UUID(), startedConnectingAt: Date())
        JMCallKitProxy.request(transaction, completion: { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            } else {
                print("Requested transaction successfully")
            }
        })
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
        let isAvailable = JMCallKitProxy.hasActiveCallForUUID(localCallUUID!.uuidString)
        print("IsCall Available: \(isAvailable)")
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

extension ViewController: JMCallKitListener {
    func providerDidReset() {
        print("providerDidReset")
    }
    
    func performAnswerCall(UUID: UUID) {
        print("performAnswerCall with answer UUID--> \(UUID.uuidString)")
        print("Configuring audio session")
        configureAvaudioSession()
    }
    
    func performEndCall(UUID: UUID) {
        print("performEndCall: \(UUID.uuidString)")
        endCallManually(withEndCallReason: .declinedElsewhere)
    }
    
    func performSetMutedCall(UUID: UUID, isMuted: Bool) {
        print("performSetMutedCall: \(UUID.uuidString), muted \(isMuted)")
        isAudioMuted = !isAudioMuted
        jitsiMeetView?.setAudioMuted(isAudioMuted)
    }
    
    func performStartCall(UUID: UUID, isVideo: Bool) {
        print("performStartCall: \(UUID.uuidString), isVideo \(isVideo)")
        print("Outgoing Call from performStartCall with UUID: \(UUID.uuidString)")
        configureAvaudioSession()
    }
    
    func providerDidActivateAudioSession(session: AVAudioSession) {
        self.callButtonsStackView.isHidden = true
        
        self.joinMeet(callID: localCallUUID ?? UUID())
    }
    
    func configureAvaudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord)
            try session.setMode(.voiceChat)
            try session.setActive(true)
        } catch let error {
            debugPrint(" audion not configured properly \(error.localizedDescription)")
        }
    }
    
    func resetAudioConfiguration() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord)
            try session.setMode(.default)
            try session.setPreferredSampleRate(44100.0)
            try session.setPreferredIOBufferDuration(0.01)
            try session.overrideOutputAudioPort(.none)
        } catch let error {
            debugPrint(" audion not configured/reset properly \(error.localizedDescription)")
        }
    }
    
    func overridingWebRTCAudioSession() {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
            try session.setMode(AVAudioSession.Mode.voiceChat.rawValue)
            try session.setPreferredSampleRate(44100.0)
            try session.setPreferredIOBufferDuration(0.005)
            
            try session.setActive(true)
        }
        catch let error {
            debugPrint("Error changeing AVAudioSession category: \(error)")
        }
        session.add(self)
        session.unlockForConfiguration()
    }
    
    func providerDidDeactivateAudioSession(session: AVAudioSession) {
        print("providerDidDeactivateAudioSession")
    }
    
    func providerTimedOutPerformingAction(action: CXAction) {
        print("providerTimedOutPerformingAction: \(action)")
    }
}

extension ViewController: RTCAudioSessionDelegate {
    func audioSessionDidChangeRoute(_ session: RTCAudioSession, reason: AVAudioSession.RouteChangeReason, previousRoute: AVAudioSessionRouteDescription) {
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: .allowBluetooth)
            try session.setMode(AVAudioSession.Mode.default.rawValue)
            //            try session.setPreferredSampleRate(44100.0)
            //            try session.setPreferredIOBufferDuration(0.005)
            // try session.overrideOutputAudioPort(.none)
        } catch let error {
            debugPrint("audioSessionDidChangeRoute error-> \(error)")
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
//
//
//extension ViewController: PKPushRegistryDelegate {
//
//    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
//        print(pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined())
//    }
//
//    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
//        print(payload)
//        isOutgoingCall = false
//        localCallUUID = UUID()
//        JMCallKitProxy.configureProvider(localizedName: jitsiTitle, ringtoneSound: nil, iconTemplateImageData: nil)
//
//        print(" startIncomingCall function-->Incoming Call UUID: \(localCallUUID!.uuidString)")
//        avatarName = jitsiIncomingParticipantName
//
//        let backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
//
//        JMCallKitProxy.reportNewIncomingCall(
//            UUID: localCallUUID!,
//            handle: jitsiTitle,
//            displayName: jitsiOutgoingParticipantName,
//            hasVideo: false
//        )  {  [unowned self] (error) in
//            guard error == nil else {
//                print("Failed, error: \(String(describing: error))")
//                self.callButtonsStackView.isHidden = false
//                return
//            }
//            print("Successfully reported")
//            self.callButtonsStackView.isHidden = true
//            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
//        }
//    }
//}
