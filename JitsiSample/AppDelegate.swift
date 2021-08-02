//
//  AppDelegate.swift
//  JitsiSample
//
//  Created by Phaninder Kumar on 20/10/20.
//

import UIKit
import JitsiMeetSDK
import PushKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate , PKPushRegistryDelegate{
    
    var window : UIWindow?
    var isAppOpendedForPuskitNotification = false
    let callManager = CallManager()
    var providerDelegate: ProviderDelegate!
    var callUUID: UUID?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        providerDelegate = ProviderDelegate(callManager: callManager)
        JMCallKitProxy.configureProvider(localizedName: "SSF App Sample",
                                         ringtoneSound: nil,
                                         iconTemplateImageData: nil)
        configureJitsiMeet()
        pushKitRegistration()
        registerForPushNotifications()
        
        return true
    }
    
   
    
    func pushKitRegistration() {
        let mainQueue = DispatchQueue.main
        let registry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
    }
    
    // MARK: UISceneSession Lifecycle
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if isAppOpendedForPuskitNotification {
            print("app opend for pushkit notification data")
            isAppOpendedForPuskitNotification = false
        }
    }
    
    // Push notification setting
        func getNotificationSettings() {
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    UNUserNotificationCenter.current().delegate = self
                    guard settings.authorizationStatus == .authorized else { return }
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            } else {
                let settings = UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil)
                UIApplication.shared.registerUserNotificationSettings(settings)
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    
    // Register push notification
        func registerForPushNotifications() {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) {
                    [weak self] granted, error in
                    guard let _ = self else {return}
                    guard granted else { return }
                    self?.getNotificationSettings()
            }
        }
}

extension AppDelegate {
    private func configureJitsiMeet() {
        
        let defaultOptions = JitsiMeetConferenceOptions.fromBuilder { (builder) in
            builder.serverURL = URL(string: "https://ssfapp.innovatorslab.net:8443/")
            builder.welcomePageEnabled = false
            builder.setFeatureFlag("help.enabled", withBoolean: false)
            builder.setFeatureFlag("add-people.enabled", withBoolean: false)
            builder.setFeatureFlag("calendar.enabled", withBoolean: false)
            builder.setFeatureFlag("close-captions.enabled", withBoolean: false)
            builder.setFeatureFlag("chat.enabled", withBoolean: false)
            builder.setFeatureFlag("invite.enabled", withBoolean: false)
            builder.setFeatureFlag("live-streaming.enabled", withBoolean: false)
            builder.setFeatureFlag("kick-out.enabled", withBoolean: false)
            builder.setFeatureFlag("security-options.enabled", withBoolean: false)
            builder.setFeatureFlag("meeting-name.enabled", withBoolean: false)
            builder.setFeatureFlag("meeting-password.enabled", withBoolean: false)
            builder.setFeatureFlag("audio-focus.disabled", withBoolean: false)
            builder.setFeatureFlag("notifications.enabled", withBoolean: false)
            builder.setFeatureFlag("video-share.enabled", withBoolean: false)
            builder.setFeatureFlag("conference-timer.enabled", withBoolean: false)
            
            builder.setFeatureFlag("call-integration.enabled", withBoolean: true)
            builder.setFeatureFlag("pip.enabled", withBoolean: true)
            builder.setFeatureFlag("raise-hand.enabled", withBoolean: true)
            builder.setFeatureFlag("toolbox.alwaysVisible", withBoolean: true)
        }
        
        JitsiMeet.sharedInstance().defaultConferenceOptions = defaultOptions
    }
}

extension AppDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        print(pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined())
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("pushRegistry:didInvalidatePushTokenForType:")
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        let backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
       let localUUID = UUID()
        providerDelegate.reportIncomingCall(uuid: localUUID, handle: Constants.jitsiTitle, displayName: Constants.jitsiOutgoingParticipantName, completion: { error in
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        })
    }
    
    func topViewControllerWithRootViewController(rootViewController: UIViewController!) -> UIViewController! {

        if rootViewController is UITabBarController {
            let tabbarController =  rootViewController as! UITabBarController
            return self.topViewControllerWithRootViewController(rootViewController: tabbarController.selectedViewController)
        } else if rootViewController is UINavigationController {
            let navigationController = rootViewController as! UINavigationController
            return self.topViewControllerWithRootViewController(rootViewController: navigationController.visibleViewController)
        } else if ((rootViewController.presentedViewController) != nil){
            let controller = rootViewController.presentedViewController
            return self.topViewControllerWithRootViewController(rootViewController: controller)
        } else {
            return rootViewController
        }

    }
}


// MARK:- UNUserNotificationCenterDelegate
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        print("didReceive ======", userInfo)
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        let userInfo = notification.request.content.userInfo
        print("willPresent ======", userInfo)
        completionHandler([.alert, .sound, .badge])
    }
}

extension UIApplication {
    class func topViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}
