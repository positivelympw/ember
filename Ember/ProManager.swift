//
//  ProManager.swift
//  Ember
//
//  Created by Marcus Win on 4/5/26.
//

import Foundation
// ProManager.swift
// Ember — Pro Tier Access Control
//
// ============================================================
// WHAT THIS FILE IS
// ============================================================
// ProManager owns the single source of truth for whether
// a user has Pro access.
//
// Two unlock paths:
//   1. StoreKit IAP — user pays through the App Store
//   2. Manual unlock — enterprise users you grant access to
//
// The rest of the app only asks one question:
//   proManager.isPro
//
// How they got Pro is irrelevant to the feature gates.
// This separation means you can add more unlock paths later
// (promo codes, referrals, trials) without touching
// any feature code.
// ============================================================
//
// ============================================================
// LESSON: Single source of truth
// Every access decision in the app reads from one place.
// If you scattered isPro checks across multiple files,
// you'd have to update all of them every time the business
// rules change. One source = one change to update everything.
// ============================================================

import Foundation
import StoreKit
import SwiftUI
import Combine

final class ProManager: ObservableObject {

    // ============================================================
    // LESSON: @Published for reactive UI
    // When isPro changes, every view reading it redraws.
    // The paywall dismisses. The feature unlocks.
    // No manual refresh needed anywhere.
    // ============================================================
    @Published var isPro: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    // StoreKit product
    @Published var proProduct: Product? = nil

    // ============================================================
    // LESSON: Two storage keys
    // manualUnlockKey: set by you for enterprise users
    // iapUnlockKey: set by StoreKit after a successful purchase
    //
    // isPro is true if EITHER key is set.
    // This means an enterprise user who later pays through
    // the App Store still works fine — redundant but harmless.
    // ============================================================
    private let manualUnlockKey = "ember.pro.manual"
    private let iapUnlockKey = "ember.pro.iap"

    // Your App Store product ID — set this when you create
    // the IAP in App Store Connect
    private let productID = "com.watchwewin.ember.pro"

    init() {
        checkProStatus()
        Task { await loadProduct() }
    }

    // MARK: Status check

    func checkProStatus() {
        let manual = UserDefaults.standard.bool(forKey: manualUnlockKey)
        let iap = UserDefaults.standard.bool(forKey: iapUnlockKey)
        isPro = manual || iap
    }

    // MARK: Manual unlock (enterprise)

    // ============================================================
    // LESSON: Manual unlock pattern
    // For enterprise clients, you call this function directly —
    // from a support tool, an admin panel, or a deep link.
    // The user never has to touch the App Store.
    //
    // In production you'd verify this server-side.
    // For now, a local flag is enough to ship and test.
    // ============================================================
    func manualUnlock() {
        UserDefaults.standard.set(true, forKey: manualUnlockKey)
        isPro = true
    }

    func manualRevoke() {
        UserDefaults.standard.removeObject(forKey: manualUnlockKey)
        checkProStatus()
    }

    // MARK: StoreKit IAP

    // ============================================================
    // LESSON: StoreKit 2
    // StoreKit 2 is Apple's modern in-app purchase framework.
    // It uses async/await — cleaner than the old callback style.
    //
    // Product.products(for:) fetches your product from Apple's
    // servers using the product ID you set in App Store Connect.
    //
    // In development the product won't load until you've created
    // it in App Store Connect and set up StoreKit testing.
    // ============================================================
    @MainActor
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            proProduct = products.first
        } catch {
            // Product not found — likely not configured in
            // App Store Connect yet. Normal during development.
            proProduct = nil
        }
    }

    // ============================================================
    // LESSON: Purchase flow
    // Product.purchase() triggers the native Apple payment sheet.
    // The user sees the price and confirms with Face ID or passcode.
    // On success, we store the unlock locally and set isPro.
    //
    // Transaction.finish() tells Apple the purchase was delivered.
    // Always call this — if you don't, Apple will keep trying
    // to re-deliver the transaction.
    // ============================================================
    @MainActor
    func purchase() async {
        guard let product = proProduct else {
            errorMessage = "Product not available. Try again later."
            return
        }

        isLoading = true
        errorMessage = ""

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    UserDefaults.standard.set(true, forKey: iapUnlockKey)
                    isPro = true
                case .unverified:
                    errorMessage = "Purchase could not be verified."
                }
            case .pending:
                errorMessage = "Purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed. Try again."
        }

        isLoading = false
    }

    // ============================================================
    // LESSON: Restore purchases
    // Required by Apple — any app with IAP must have a
    // restore purchases option. Users who reinstall or switch
    // devices use this to get their purchases back.
    //
    // AppStore.sync() re-validates all transactions with Apple.
    // ============================================================
    @MainActor
    func restorePurchases() async {
        isLoading = true
        do {
            try await AppStore.sync()
            // Re-check entitlements after sync
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result,
                   transaction.productID == productID {
                    UserDefaults.standard.set(true, forKey: iapUnlockKey)
                    isPro = true
                }
            }
        } catch {
            errorMessage = "Restore failed. Try again."
        }
        isLoading = false
    }
}
