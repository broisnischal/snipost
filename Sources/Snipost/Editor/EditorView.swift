import SwiftUI

struct EditorView: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        HStack(spacing: 0) {
            previewPane
            Divider()
            controls
                .frame(width: 264)
                .padding(16)
        }
        .frame(minWidth: 860, minHeight: 540)
    }

    private var previewPane: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
            if let preview = model.preview {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("Background") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    swatch(
                        colors: model.autoColors,
                        label: "Auto",
                        isSelected: model.settings.background == .auto
                    ) { model.settings.background = .auto }

                    ForEach(GradientPreset.all) { preset in
                        swatch(
                            colors: preset.colors,
                            label: preset.name,
                            isSelected: model.settings.background == .preset(preset)
                        ) { model.settings.background = .preset(preset) }
                    }

                    transparentSwatch
                }
            }

            section("Padding") {
                Slider(value: $model.settings.paddingFraction, in: 0.02...0.25)
            }

            section("Corner radius") {
                Slider(value: $model.settings.cornerRadius, in: 0...48)
            }

            section("Shadow") {
                Slider(value: $model.settings.shadowOpacity, in: 0...0.9)
            }

            section("Canvas") {
                Picker("", selection: $model.settings.aspect) {
                    ForEach(AspectPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Spacer()

            HStack {
                Text(model.outputSizeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let message = model.lastSaveMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            VStack(spacing: 8) {
                Button {
                    model.copyToClipboard()
                } label: {
                    Label(model.justCopied ? "Copied" : "Copy", systemImage: model.justCopied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("c", modifiers: .command)

                HStack(spacing: 8) {
                    Button("Save to Desktop") { model.saveToDesktop() }
                        .frame(maxWidth: .infinity)
                    Button("Save…") { model.saveAs() }
                        .frame(maxWidth: .infinity)
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func swatch(colors: [RGB], label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let gradient = LinearGradient(
            colors: colors.map { Color(red: Double($0.r), green: Double($0.g), blue: Double($0.b)) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return RoundedRectangle(cornerRadius: 6)
            .fill(gradient)
            .frame(height: 36)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            )
            .onTapGesture(perform: action)
            .help(label)
    }

    private var transparentSwatch: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(nsColor: .quaternaryLabelColor))
            .frame(height: 36)
            .overlay(Image(systemName: "square.slash").foregroundStyle(.secondary))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        model.settings.background == .transparent ? Color.accentColor : Color.primary.opacity(0.12),
                        lineWidth: model.settings.background == .transparent ? 2 : 1
                    )
            )
            .onTapGesture { model.settings.background = .transparent }
            .help("Transparent")
    }
}
