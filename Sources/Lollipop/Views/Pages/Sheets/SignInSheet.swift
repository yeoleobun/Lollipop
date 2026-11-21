import AppKit
import SwiftUI

/// Modeled directly after macOS 27 Apple Podcasts' centered Account / Login modal:
/// centered app icon at top, bold title, generous white space, subtle privacy note,
/// and pill-shaped Cancel / Primary buttons at bottom-right.
struct SignInSheet: View {
    let engine: YouTubeMusicEngine
    @Environment(\.dismiss) private var dismiss

    @ViewState private var showingGoogleLoginWeb = false

    var body: some View {
        Group {
            if engine.isSignedIn {
                appleStyleAccountView
            } else if showingGoogleLoginWeb {
                googleSignInWebModal
            } else {
                appleStyleSignInIntroView
            }
        }
        .pageBackground()
    }

    // MARK: - Sign-In Intro Modal

    private var appleStyleSignInIntroView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                appIconHeader
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.signInWithGoogle)
                        .font(AppTypography.signInIntroTitle)
                        .foregroundStyle(.primary)

                    Text(L10n.signInIntroDescription)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
            }
            .padding(.horizontal, 36)
            .padding(.top, 24)

            Spacer(minLength: 36)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: AppSymbols.peopleFill)
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.accent)

                    Text(L10n.signInSessionNotice)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Spacer()

                    Button(L10n.cancel) {
                        dismiss()
                    }
                    .buttonStyle(
                        SecondaryCapsuleButtonStyle(
                            horizontalPadding: 18,
                            verticalPadding: 7,
                            font: .system(size: 13, weight: .medium),
                            fill: AppColors.secondaryCancelPillFill
                        )
                    )
                    .keyboardShortcut(.cancelAction)

                    Button(L10n.signIn) {
                        withAnimation(AppAnimations.standard) {
                            showingGoogleLoginWeb = true
                        }
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle(horizontalPadding: 22, verticalPadding: 7))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 26)
        }
        .frame(
            width: AppMetrics.signInIntroSize.width,
            height: AppMetrics.signInIntroSize.height
        )
    }

    // MARK: - Compact Google Sign-In WebView Step

    private var googleSignInWebModal: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 26, height: 26)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.signInWithGoogle)
                        .font(.system(size: 13.5, weight: .semibold))
                    Text(L10n.autofillTip)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(L10n.cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            GoogleSignInWebView {
                engine.handleGoogleSignInCompleted()
                dismiss()
            }
        }
        .frame(
            width: AppMetrics.signInWebSize.width,
            height: AppMetrics.signInWebSize.height
        )
    }

    // MARK: - Signed-In Account View

    private var appleStyleAccountView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                if !engine.playerState.accountAvatarURL.isEmpty {
                    ArtworkView(
                        urlString: engine.playerState.accountAvatarURL,
                        size: 72,
                        cornerRadius: 36,
                        isCircular: true
                    )
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
                } else {
                    appIconHeader
                }

                VStack(spacing: 4) {
                    Text(
                        engine.playerState.accountName.isEmpty
                            ? L10n.defaultServiceName
                            : engine.playerState.accountName
                    )
                    .font(AppTypography.accountTitle)

                    Text(
                        engine.playerState.accountEmail.isEmpty
                            ? L10n.connectedAudioOnlyMode
                            : engine.playerState.accountEmail
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 32)
            .padding(.horizontal, 36)

            Spacer(minLength: 28)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: AppSymbols.peopleFill)
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.accent)

                    Text(L10n.syncedNotice)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button(L10n.showEmbeddedPlayer) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            engine.showEmbeddedPlayerSheet = true
                        }
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 12))

                    Spacer()

                    Button(L10n.signOut) {
                        Task { await engine.signOut() }
                    }
                    .buttonStyle(DestructiveCapsuleButtonStyle())

                    Button(L10n.done) {
                        dismiss()
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle(horizontalPadding: 20, verticalPadding: 7))
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 26)
        }
        .frame(
            width: AppMetrics.accountSheetSize.width,
            height: AppMetrics.accountSheetSize.height
        )
    }

    private var appIconHeader: some View {
        Group {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.accent.gradient)
                        .frame(width: 68, height: 68)
                    Image(systemName: AppSymbols.fallbackAppIcon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
