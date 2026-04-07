// ProPaywallView.swift
// Ember — Pro Upgrade Paywall

import SwiftUI
import StoreKit

struct ProPaywallView: View {
    @ObservedObject var proManager: ProManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    paywallHeader
                    featureList.padding(.top, 32)
                    purchaseSection.padding(.top, 32)
                    Button {
                        Task { await proManager.restorePurchases() }
                    } label: {
                        Text("Restore purchases")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
            .background(Color(red: 0.97, green: 0.96, blue: 0.94))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.6))
                            .font(.system(size: 22))
                    }
                }
            }
            .onChange(of: proManager.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    var paywallHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundColor(Color(red: 0.18, green: 0.77, blue: 0.71))
            }
            .padding(.top, 32)

            Text("Ember Pro")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color(red: 0.06, green: 0.05, blue: 0.04))

            Text("Document intelligence and advanced\ncoordination for serious users.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    var featureList: some View {
        VStack(spacing: 0) {
            ProFeatureRow(icon: "doc.text.magnifyingglass",
                          title: "Document intelligence",
                          description: "Upload PDFs. Clients ask questions. Ember answers from the actual document.",
                          isPro: true)
            Divider().padding(.leading, 56)
            ProFeatureRow(icon: "person.3.fill",
                          title: "Unlimited groups",
                          description: "No cap on groups or circle size.",
                          isPro: true)
            Divider().padding(.leading, 56)
            ProFeatureRow(icon: "waveform",
                          title: "Voice output",
                          description: "Ember speaks responses back to you.",
                          isPro: true)
            Divider()
            ProFeatureRow(icon: "person.2.fill",
                          title: "Personal circle",
                          description: "Add people, build context, coordinate.",
                          isPro: false)
            Divider().padding(.leading, 56)
            ProFeatureRow(icon: "bubble.left.fill",
                          title: "SMS drafting",
                          description: "Ember drafts. You review and send.",
                          isPro: false)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var purchaseSection: some View {
        VStack(spacing: 12) {
            if proManager.isLoading {
                ProgressView().tint(Color(red: 0.18, green: 0.77, blue: 0.71)).padding(.vertical, 20)
            } else {
                if let product = proManager.proProduct {
                    Text(product.displayPrice + " / year")
                        .font(.system(size: 15)).foregroundColor(.gray)
                }
                Button {
                    Task { await proManager.purchase() }
                } label: {
                    HStack {
                        Spacer()
                        Text("Upgrade to Pro")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(Color(red: 0.18, green: 0.77, blue: 0.71))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                if !proManager.errorMessage.isEmpty {
                    Text(proManager.errorMessage)
                        .font(.system(size: 13)).foregroundColor(.red).multilineTextAlignment(.center)
                }
                Text("Payment charged to your Apple ID. Renews annually unless cancelled.")
                    .font(.system(size: 11)).foregroundColor(.gray)
                    .multilineTextAlignment(.center).lineSpacing(3).padding(.top, 4)
            }
        }
    }
}

struct ProFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let isPro: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(isPro
                          ? Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.12)
                          : Color.gray.opacity(0.08))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isPro ? Color(red: 0.18, green: 0.77, blue: 0.71) : .gray)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(red: 0.06, green: 0.05, blue: 0.04))
                    Text(isPro ? "Pro" : "Free")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isPro ? Color(red: 0.18, green: 0.77, blue: 0.71) : .gray)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(isPro
                                    ? Color(red: 0.18, green: 0.77, blue: 0.71).opacity(0.1)
                                    : Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                }
                Text(description)
                    .font(.system(size: 13)).foregroundColor(.gray).lineSpacing(3)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    ProPaywallView(proManager: ProManager())
}
