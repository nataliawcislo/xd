//
//  LoginLogoutHelper.swift
//  Buergerbus
//
//  Created by Jacques Marco Jung on 25.04.19.
//  Copyright © 2019 Thrive. All rights reserved.
//

import UIKit
import KeychainSwift
import UIKit

struct Login {

    private static var loginViewController: LoginViewController?
    static var loginService: LoginService?
    static var sync: Sync?

    private static let keychain = KeychainSwift()

    private static func showLogin() {
        Logger.trace("")
        
        if loginViewController == nil {
            let storyboard = UIStoryboard(name: "Login", bundle: nil)
            loginViewController = storyboard.instantiateInitialViewController() as? LoginViewController
            if let loginService = loginService {
                loginViewController?.presenter = LoginPresenter(loginService: loginService)
            }
        }

        Status.showLoginViewController(loginViewController)
    }

    private static func logout() {
        Logger.trace("")
        
        keychain.clear()
        showLogin()
        Status.hideStatusMessage()
    }

    static func retryLogin() {
        Logger.trace("")
        if !(loginService?.loggedIn() ?? false) {
            self.tryLogin()
        }
    }

    static func checkIfLoggedIn() -> Bool {
        Logger.trace("")

        guard let loginService = loginService else {
            return false
        }

        return loginService.loggedIn()
    }

    static func logoutIfNeeded() {
        Logger.trace("")
        
        if Preferences.didServerChange {
            Logger.info("Logging out: Server changed.")
            DatabaseService().deleteAll()
        } else if Preferences.logoutAtNextAppStart {
            Logger.info("Logging out: Manual logout was set in settings.")
        } else {
            return
        }

        loginService?.logout(success: nil)
        Preferences.resetLogoutValue()
        keychain.clear()
    }

    static func tryLogin() {
        Logger.trace("")
        
        guard let username = keychain.get(KeychainConfig.username), let password = keychain.get(KeychainConfig.password) else {
            Logger.info("Logging out: username and/or password not found in keychain.")
            self.logout()
            return
        }
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true

        loginService?.login(username: username, password: password, success: { (user) in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            Logger.info("Login successful. Username: \(username) // Password: \(password)")

            Status.showStatusMessage("hint.loadingData".localized())
            sync?.sync()
            
        }, failure: { error in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            Logger.error("Login failed: \(error.localizedDescription)")

            let errorCode = (error as NSError).code
            if errorCode != URLError.notConnectedToInternet.rawValue && errorCode != URLError.timedOut.rawValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                    self.logout()
                })
            }
        })
    }
    

}
