import SwiftUI

struct PopupView: View {
    @ObservedObject var model: PopupModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch model.phase {
            case .noSelection:
                noSelection
            case .choosing:
                preview
                actionGrid
            case .running, .done:
                header
                resultView
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                buttons
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(.regularMaterial)
    }

    private var noSelection: some View {
        VStack(spacing: 6) {
            Image(systemName: "text.cursor").font(.title2).foregroundStyle(.secondary)
            Text("Select some text first, then press ⌥ Space.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var preview: some View {
        Text(model.text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
            ForEach(model.actions) { action in
                Button {
                    model.run(action)
                } label: {
                    Label(action.title, systemImage: action.icon)
                        .font(.callout)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var header: some View {
        HStack {
            Button { model.back() } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            if let action = model.action {
                Label(action.title, systemImage: action.icon).font(.callout.weight(.medium))
            }
            Spacer()
            if model.phase == .running { ProgressView().controlSize(.small) }
        }
    }

    private var resultView: some View {
        ScrollView {
            Text(model.result.isEmpty && model.phase == .running ? "…" : model.result)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 40, maxHeight: 220)
    }

    private var buttons: some View {
        HStack {
            Button("Copy") { model.copy() }
                .keyboardShortcut("c", modifiers: .command)
            Spacer()
            Button("Cancel") { model.cancel() }
                .keyboardShortcut(.cancelAction)
            Button("Replace") { model.replace() }
                .keyboardShortcut(.defaultAction)
                .disabled(model.phase != .done || model.result.isEmpty)
        }
        .controlSize(.regular)
    }
}
