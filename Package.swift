// swift-tools-version:5.0
import PackageDescription

let package = Package(
  name: "EEMetalTextureViewer",
  products: [
    .library(
      name: "EEMetalTextureViewer",
      targets: ["EEMetalTextureViewer"]
    )
  ],
  targets: [
    .target(
      name: "EEMetalTextureViewer",
      dependencies: [],
      path: "EEMetalTextureViewer"
    )
  ]
)
