import SwiftUI

struct EditorView: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        HStack(spacing: 0) {
            previewPane
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        backgroundSection
                        wallpaperSection
                        customColorSection
                        filterSection
                        cursorSection
                        sliderSection
                        canvasSection
                        formatSection
                    }
                    .padding(.bottom, 8)
                }
                footer
            }
            .frame(width: 272)
            .padding(16)
        }
        .frame(minWidth: 900, minHeight: 580)
    }

    // MARK: Preview

    private var previewPane: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
            if let preview = model.preview {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            model.placeCursor(atNormalized: CGPoint(
                                                x: value.location.x / max(geo.size.width, 1),
                                                y: value.location.y / max(geo.size.height, 1)
                                            ))
                                        }
                                )
                        }
                    )
                    .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Sections

    private var backgroundSection: some View {
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

                iconSwatch(
                    systemImage: "photo",
                    label: "Image file…",
                    isSelected: model.settings.background == .image && model.selectedWallpaper == nil
                ) { model.chooseBackgroundImage() }

                iconSwatch(
                    systemImage: "square.slash",
                    label: "Transparent",
                    isSelected: model.settings.background == .transparent
                ) { model.settings.background = .transparent }
            }
        }
    }

    private var wallpaperSection: some View {
        Group {
            if !model.wallpapers.isEmpty {
                section("macOS wallpapers") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(model.wallpapers) { wallpaper in
                                wallpaperThumb(wallpaper)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(height: 42)
                }
            }
        }
    }

    private func wallpaperThumb(_ wallpaper: Wallpaper) -> some View {
        let isSelected = model.selectedWallpaper == wallpaper.url && model.settings.background == .image
        return Group {
            if let thumb = model.thumbnails[wallpaper.url] {
                Image(nsImage: thumb).resizable().scaledToFill()
            } else {
                Color.primary.opacity(0.08)
            }
        }
        .frame(width: 58, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture { model.selectWallpaper(wallpaper) }
        .help(wallpaper.name)
    }

    private var customColorSection: some View {
        section("Custom color") {
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    ColorPicker("", selection: $model.customSolid, supportsOpacity: false)
                        .labelsHidden()
                    Text("Solid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: model.customSolid) { model.applyCustomSolid() }

                HStack(spacing: 6) {
                    ColorPicker("", selection: $model.customGradientStart, supportsOpacity: false)
                        .labelsHidden()
                    ColorPicker("", selection: $model.customGradientEnd, supportsOpacity: false)
                        .labelsHidden()
                    Text("Gradient")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: model.customGradientStart) { model.applyCustomGradient() }
                .onChange(of: model.customGradientEnd) { model.applyCustomGradient() }
            }
        }
    }

    private var filterSection: some View {
        section("Effect") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(ImageFilter.allCases) { filter in
                    let isSelected = model.settings.filter == filter
                    Text(filter.rawValue)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .onTapGesture { model.settings.filter = filter }
                }
            }
        }
    }

    private var cursorSection: some View {
        section("Cursor") {
            HStack(spacing: 6) {
                ForEach(CursorStyle.allCases) { style in
                    Button {
                        model.settings.cursor = style
                    } label: {
                        Image(systemName: style.symbolName)
                            .frame(width: 28, height: 22)
                    }
                    .buttonStyle(.bordered)
                    .tint(model.settings.cursor == style ? Color.accentColor : nil)
                    .help(style.rawValue)
                }
            }
            if model.settings.cursor != .none {
                Slider(value: $model.settings.cursorSize, in: 32...220)
                Text("Drag on the preview to position the cursor")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sliderSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("Padding") {
                Slider(value: $model.settings.paddingFraction, in: 0.02...0.25)
            }
            section("Corner radius") {
                Slider(value: $model.settings.cornerRadius, in: 0...48)
            }
            section("Shadow") {
                Slider(value: $model.settings.shadowOpacity, in: 0...0.9)
            }
        }
    }

    private var canvasSection: some View {
        section("Canvas") {
            Picker("", selection: $model.settings.aspect) {
                ForEach(AspectPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var formatSection: some View {
        section("Format") {
            Picker("", selection: $model.settings.exportFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
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

    // MARK: Building blocks

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

    private func iconSwatch(systemImage: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(nsColor: .quaternaryLabelColor))
            .frame(height: 36)
            .overlay(Image(systemName: systemImage).foregroundStyle(.secondary))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            )
            .onTapGesture(perform: action)
            .help(label)
    }
}
