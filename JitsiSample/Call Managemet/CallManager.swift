/// Copyright (c) 2019 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import CallKit
import JitsiMeetSDK

class CallManager {
  var callsChangedHandler: (() -> Void)?
  private(set) var calls: [Call] = []

  func callWithUUID(uuid: UUID) -> Call? {
    guard let index = calls.firstIndex(where: { $0.uuid == uuid }) else {
      return nil
    }
    return calls[index]
  }
  
  func add(call: Call) {
    calls.append(call)
    call.stateChanged = { [weak self] in
      guard let self = self else { return }
      self.callsChangedHandler?()
    }
    callsChangedHandler?()
  }
  
  func startCall(handle: String, videoEnabled: Bool) {
    // 1
    removeAllCalls()
    let handle = CXHandle(type: .generic, value: Constants.jitsiIncomingParticipantName)
    // 2
    let uuid = UUID()
    let startCallAction = CXStartCallAction(call: uuid, handle: handle)
    // 3
    startCallAction.isVideo = videoEnabled
    let call = Call(uuid:uuid, outgoing: true,
                    handle: Constants.jitsiIncomingParticipantName)
    add(call: call)
    let transaction = CXTransaction(action: startCallAction)
    requestTransaction(transaction)
  }
  
  func end(call: Call) {
    // 1.
    
    let endCallAction = CXEndCallAction(call: call.uuid)
    // 2.
    let transaction = CXTransaction(action: endCallAction)
    
    requestTransaction(transaction)
  }
  
  func setHeld(call: Call, onHold: Bool) {
    let setHeldCallAction = CXSetHeldCallAction(call: call.uuid, onHold: onHold)
    let transaction = CXTransaction()
    transaction.addAction(setHeldCallAction)
    
    requestTransaction(transaction)
  }

  // 3.
  private func requestTransaction(_ transaction: CXTransaction) {
    JMCallKitProxy.request(transaction) { error in
      if let error = error {
        print("Error requesting transaction: \(error)")
      } else {
        print("Requested transaction successfully")
      }
    }
  }
  
  func remove(call: Call) {
    guard let index = calls.firstIndex(where: { $0 === call }) else { return }
    calls.remove(at: index)
    callsChangedHandler?()
  }
  
  func removeAllCalls() {
    calls.removeAll()
    callsChangedHandler?()
  }
}
