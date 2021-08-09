//
//  ProviderDelegate.swift
//  JitsiSample
//
//  Created by Imran Sayeed on 28/7/21.
//

import Foundation
import AVFoundation
import JitsiMeetSDK
import CallKit

class ProviderDelegate: NSObject {
    private var isAudioMuted = false
    private var jitsiMeetView: JitsiMeetView?
    private let callManager: CallManager
    private let roomName = "SampleJitsiAppRoom101"
    private var isViewPresenting = false
    let customView = CustomView()
    init(callManager: CallManager) {
        self.callManager = callManager
        super.init()
        JMCallKitProxy.addListener(self)
    }
    
    func reportIncomingCall(
        uuid: UUID,
        handle: String,
        displayName: String,
        hasVideo: Bool = false,
        completion: ((Error?) -> Void)?
    ) {
        
        JMCallKitProxy.reportNewIncomingCall(
            UUID: uuid,
            handle: handle,
            displayName: displayName,
            hasVideo: false
        ) { error in
            if error == nil {
                let call = Call(uuid: uuid, handle: handle, isAudioCall: !hasVideo)
                self.callManager.add(call: call)
            }
            completion?(error)
        }
    }
    
    private func showJitsiView() {
        if let viewController = UIApplication.topViewController() as? ViewController {
            customView.callManager = callManager
            customView.call = callManager.callWithUUID(uuid: callManager.calls.first?.uuid ?? UUID())
            viewController.view.addSubview(customView)
            customView.frame = viewController.view.bounds
            customView.joinMeet()
        }
//        if var topController = UIApplication.shared.keyWindow?.rootViewController {
//            while let presentedViewController = topController.presentedViewController {
//                topController = presentedViewController
//            }
//            if !isViewPresenting {
//                jitsiView(for: topController)
//                isViewPresenting = true
//            }
//        }
    }
    
    fileprivate func jitsiView(for view: UIViewController = UIViewController()){
        let jitsi = JitsiMeetViewController()
        jitsi.callManager = callManager
        jitsi.call = callManager.callWithUUID(uuid: callManager.calls.first?.uuid ?? UUID())
        jitsi.modalPresentationStyle = .fullScreen
        view.present(jitsi, animated: true, completion: nil)
    }
    
    private func dismissView() {
        isViewPresenting = false
        if var topController = UIApplication.shared.keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            topController.dismiss(animated: true, completion: nil)
        }
    }
}

extension ProviderDelegate: JMCallKitListener {
    func providerDidReset() {
        print("providerDidReset")
        for call in callManager.calls {
            call.end()
        }
        
        callManager.removeAllCalls()
        customView.removeFromSuperview()
    }
    
    func performAnswerCall(UUID: UUID) {
        print("performAnswerCall with answer UUID--> \(UUID.uuidString)")
        print("Configuring audio session")
        guard let call = callManager.callWithUUID(uuid: UUID) else {
            return
        }
        callManager.add(call: call)
        configureAvaudioSession()
    }
    
    func performEndCall(UUID: UUID) {
        print("performEndCall: \(UUID.uuidString)")
        isViewPresenting = false
        dismissView()
        guard let call = callManager.callWithUUID(uuid: UUID) else {
            
            return
        }
        call.end()
        callManager.end(call: call)
        callManager.remove(call: call)
        
    }
    
    func performSetMutedCall(UUID: UUID, isMuted: Bool) {
        print("performSetMutedCall: \(UUID.uuidString), muted \(isMuted)")
        isAudioMuted = !isAudioMuted
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: Constants.callMutedKey), object: nil, userInfo: [Constants.callMuted: isAudioMuted])
    }
    
    func performStartCall(UUID: UUID, isVideo: Bool) {
        print("performStartCall: \(UUID.uuidString), isVideo \(isVideo)")
        print("Outgoing Call from performStartCall with UUID: \(UUID.uuidString)")
        configureAvaudioSession()
    }
    
    func providerDidActivateAudioSession(session: AVAudioSession) {
        showJitsiView()
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
    
    func providerDidDeactivateAudioSession(session: AVAudioSession) {
        print("providerDidDeactivateAudioSession")
    }
    
    func providerTimedOutPerformingAction(action: CXAction) {
        print("providerTimedOutPerformingAction: \(action)")
    }
}
