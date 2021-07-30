//
//  Call.swift
//  JitsiSample
//
//  Created by Imran Sayeed on 29/7/21.
//

import Foundation

enum CallState {
    case connecting
    case active
    case held
    case ended
}

enum ConnectedState {
    case pending
    case complete
}

class Call {
    let uuid: UUID
    let outgoing: Bool
    let handle: String
    let isAudioCall: Bool
    
    var state: CallState = .ended {
        didSet {
            stateChanged?()
        }
    }
    
    var connectedState: ConnectedState = .pending {
        didSet {
            connectedStateChanged?()
        }
    }
    
    var stateChanged: (() -> Void)?
    var connectedStateChanged: (() -> Void)?
    
    init(uuid: UUID, outgoing: Bool = false, handle: String, isAudioCall: Bool = true) {
        self.uuid = uuid
        self.outgoing = outgoing
        self.handle = handle
        self.isAudioCall = isAudioCall
    }
    
    func start(completion: ((_ success: Bool) -> Void)?) {
        completion?(true)
        
        self.state = .active
        self.connectedState = .complete
    }
    
    func answer() {
        state = .active
    }
    
    func end() {
        state = .ended
    }
}
