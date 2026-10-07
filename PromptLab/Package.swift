// swift-tools-version: 6.2
//
// PromptLab: tries prompts on the Mac's on-device Apple Intelligence model with
// fake, precomputed metrics, to see what the model can and can't do before we
// build a feature on it. Not part of the app (it lives outside Compass/).
//
//   swift run -c release --package-path PromptLab PromptLab            all variants, 3 runs each
//   swift run -c release --package-path PromptLab PromptLab CD --runs=1  only variants C and D, once
//
// Needs Apple Intelligence turned on in the Mac's System Settings.

import PackageDescription

let package = Package(
    name: "PromptLab",
    platforms: [.macOS("26.4")],
    targets: [
        .executableTarget(name: "PromptLab", swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
