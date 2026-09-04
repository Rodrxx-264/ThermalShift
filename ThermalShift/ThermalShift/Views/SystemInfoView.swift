import SwiftUI
import AppKit

struct SystemInfoView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                WindowBackground()
                    .ignoresSafeArea()

                if let info = appState.systemInfo {
                    ScrollView {
                        VStack(spacing: 18) {
                            hero(in: info)
                            rows(in: info)
                        }
                        .padding(26)
                    }
                } else {
                    ProgressView()
                }
            }

            Divider()

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .padding(12)
        }
        .frame(width: 420, height: 460)
    }

    private func hero(in info: SystemInfo) -> some View {
        VStack(spacing: 10) {
            if let path = info.modelImagePath,
               let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)
            } else {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                    .frame(height: 110)
            }

            VStack(spacing: 2) {
                Text(info.machineName)
                    .font(.system(size: 20, weight: .bold))

                Text(info.modelName == info.machineName ? info.modelIdentifier : info.modelName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func rows(in info: SystemInfo) -> some View {
        VStack(spacing: 8) {
            row("Chip", info.cpuName)
            row("Memory", "\(info.memoryGB) GB")
            if !info.gpuList.isEmpty {
                ForEach(info.gpuList, id: \.self) { gpu in
                    row("Graphics", gpu)
                }
            }
            if !info.storageDescription.isEmpty {
                row("Storage", info.storageDescription)
            }
            row("macOS", info.osVersionString)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.5))
        }
    }
}

#Preview {
    SystemInfoView()
        .environment(AppState())
}