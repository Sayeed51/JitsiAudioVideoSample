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
    
    @IBOutlet weak var callButtonsStackView: UIStackView!
    
    deinit {
        JMCallKitProxy.callKitProvider?.invalidate()
    }
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func reportIncomingCallButtonTapped(_ sender: UIButton) {
        startIncomingCall()
    }
    
    @IBAction func initiateOutgoingCallButtonTapped(_ sender: UIButton) {
        startOutgoingCall()
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
        appdelegate.callManager.startCall(handle: Constants.jitsiIncomingParticipantName, videoEnabled: false)
    }
}
