import AppKit

// Headless modes (used for CI / render verification, no UI):
//   Snipost --beautify <input.png> <output.png>   render a file through the pipeline
//   Snipost --selftest <output.png>               render a synthetic screenshot
let arguments = CommandLine.arguments
if arguments.count >= 2 {
    switch arguments[1] {
    case "--beautify" where arguments.count == 4:
        HeadlessRender.beautify(inputPath: arguments[2], outputPath: arguments[3])
        exit(0)
    case "--selftest" where arguments.count == 3:
        HeadlessRender.selftest(outputPath: arguments[2])
        exit(0)
    case "--stitchtest" where arguments.count == 3:
        HeadlessRender.stitchTest(outputPath: arguments[2])
        exit(0)
    case "--ocrtest":
        HeadlessRender.ocrTest()
        exit(0)
    case "--help", "-h":
        print("""
        Snipost — minimal screenshot beautifier for macOS
          (no arguments)                     run the menu bar app
          --beautify <in.png> <out.png>      beautify an existing image, headless
          --selftest <out.png>               render a synthetic test image, headless
        """)
        exit(0)
    default:
        break
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run() // never returns; `delegate` stays alive in this scope
}
