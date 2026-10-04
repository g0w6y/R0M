import SwiftUI

struct CleanerView: View {
    @EnvironmentObject var sampler: Sampler
    @Local private var selected = Set<String>()
    @Local private var expanded = Set<String>()
    @Local private var mode: CleanMode = .trash
    @Local private var confirming = false

    private var groups: [(CleanLocation, [CleanItem])] {
        Cleaner.locations.compactMap { loc in
            let items = sampler.cleanItems.filter { $0.location.id == loc.id }
            return items.isEmpty ? nil : (loc, items)
        }
    }
    private var selectedItems: [CleanItem] { sampler.cleanItems.filter { selected.contains($0.id) } }
    private var selectedSize: UInt64 { selectedItems.reduce(0) { $0 + $1.size } }
    private var totalSize: UInt64 { sampler.cleanItems.reduce(0) { $0 + $1.size } }
    private var includesSystem: Bool { selectedItems.contains { $0.location.scope == .system } }

    var body: some View {
        SectionScaffold(title: "Cleaner", subtitle: "Find regenerable caches and logs — user level and system level") {
            HStack(spacing: UI.gridSpacing) {
                StatTile(label: "Found", value: Formatters.fileBytes(totalSize), sub: "\(sampler.cleanItems.count) items", systemImage: "externaldrive.badge.xmark", accent: .brown)
                StatTile(label: "Selected", value: Formatters.fileBytes(selectedSize), sub: "\(selected.count) item(s)", systemImage: "checkmark.circle", accent: .brown)
                StatTile(label: "In Trash", value: sampler.trashBytes.map(Formatters.fileBytes) ?? "n/a",
                         sub: sampler.trashBytes == nil ? "needs Full Disk Access to read" : nil, systemImage: "trash", accent: .brown)
            }

            if let msg = sampler.lastCleanMessage {
                Card { Label(msg, systemImage: sampler.lastCleanOK ? "checkmark.seal" : "exclamationmark.triangle")
                    .font(.system(size: 12)).foregroundStyle(sampler.lastCleanOK ? .green : .orange) }
            }

            HStack(spacing: 10) {
                Button { sampler.scanCleaner(); selected.removeAll() } label: { Label("Rescan", systemImage: "arrow.clockwise") }
                    .disabled(sampler.cleanScanning)
                Button { selectSafe() } label: { Label("Select safe", systemImage: "checkmark.shield") }
                    .disabled(sampler.cleanItems.isEmpty)
                Button(role: .destructive) { confirming = true } label: { Label("Clean selected", systemImage: "sparkles") }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty || sampler.cleanScanning)
                Spacer()
                Picker("", selection: $mode) {
                    ForEach(CleanMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 270)
                if sampler.cleanScanning { ProgressView().controlSize(.small) }
            }
            .confirmationDialog(confirmTitle, isPresented: $confirming, titleVisibility: .visible) {
                Button(mode == .trash && !includesSystem ? "Move to Trash" : "Clean now", role: .destructive) {
                    sampler.clean(selectedItems, mode: mode)
                    selected.removeAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text(confirmMessage) }

            if groups.isEmpty {
                Card {
                    Text(sampler.cleanScanning ? "Scanning…" : "Nothing to clean — all locations are empty.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            ForEach(groups, id: \.0.id) { loc, items in locationCard(loc, items) }

            Card(title: "One-tap system actions", systemImage: "wrench.and.screwdriver", accent: .brown) {
                VStack(alignment: .leading, spacing: 10) {
                    actionRow("Empty Trash", "Permanently removes everything in the Trash (Finder).", "trash") {
                        sampler.runCleanerAction { Cleaner.emptyTrash() }
                    }
                    Divider()
                    actionRow("Flush DNS cache", "Fixes stale lookups. Asks for your password.", "network") {
                        sampler.runCleanerAction { Cleaner.flushDNS() }
                    }
                    Divider()
                    actionRow("Purge inactive memory", "Drops the disk cache held in RAM. Asks for your password; macOS refills it as needed.", "memorychip") {
                        sampler.runCleanerAction { Cleaner.purgeMemory() }
                    }
                }
            }

            Text("Safety: R0M only touches the fixed folders listed above — never documents, photos, mail, or app data. User items go to the Trash by default (space is freed once you empty it). System items need admin rights and are removed permanently; anything protected by macOS is skipped. Items for apps that are running right now are marked “in use” and not selected for you.")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .onAppear { if !sampler.cleanHasScanned { sampler.scanCleaner() } }
    }

    private func locationCard(_ loc: CleanLocation, _ items: [CleanItem]) -> some View {
        let total = items.reduce(UInt64(0)) { $0 + $1.size }
        let isOpen = expanded.contains(loc.id)
        let shown = isOpen ? items : Array(items.prefix(5))
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(loc.title).font(.system(size: 13, weight: .semibold))
                    badge(loc.scope == .system ? "ADMIN" : "USER", loc.scope == .system ? .orange : .blue)
                    if loc.risk == .review { badge("REVIEW", .yellow) }
                    Spacer()
                    Text(Formatters.fileBytes(total)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                    Button(allSelected(items) ? "None" : "All") { toggleAll(items) }
                        .buttonStyle(.link).font(.system(size: 11))
                }
                Text(loc.detail).font(.system(size: 10)).foregroundStyle(.secondary)
                Divider()
                ForEach(shown) { item in
                    HStack {
                        Image(systemName: selected.contains(item.id) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(selected.contains(item.id) ? Color.accentColor : Color.secondary)
                        Text(item.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        if item.inUse { badge("IN USE", .red) }
                        Spacer(minLength: 8)
                        Text(Formatters.fileBytes(item.size)).font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(item.id) }
                }
                if items.count > 5 {
                    Button(isOpen ? "Show fewer" : "Show all \(items.count)") {
                        if isOpen { expanded.remove(loc.id) } else { expanded.insert(loc.id) }
                    }
                    .buttonStyle(.link).font(.system(size: 11))
                }
            }
        }
    }

    private func actionRow(_ title: String, _ detail: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(.brown)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Run", action: action).disabled(sampler.cleanScanning)
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text).font(.system(size: 8, weight: .bold)).tracking(0.5)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule()).foregroundStyle(color)
    }

    private var confirmTitle: String {
        if includesSystem { return "Clean \(selected.count) item(s) including system folders?" }
        return mode == .trash ? "Move \(selected.count) item(s) to the Trash?" : "Permanently delete \(selected.count) item(s)?"
    }
    private var confirmMessage: String {
        var parts = ["\(Formatters.fileBytes(selectedSize)) selected."]
        if includesSystem { parts.append("System items need your password and are deleted permanently; protected ones are skipped.") }
        if mode == .delete { parts.append("Deleted items cannot be recovered. Caches are rebuilt by the apps that own them.") }
        else { parts.append("You can restore them from the Trash. Empty the Trash to free the space.") }
        return parts.joined(separator: " ")
    }

    private func toggle(_ id: String) { if selected.contains(id) { selected.remove(id) } else { selected.insert(id) } }
    private func allSelected(_ items: [CleanItem]) -> Bool { items.allSatisfy { selected.contains($0.id) } }
    private func toggleAll(_ items: [CleanItem]) {
        let usable = items.filter { !$0.inUse }.map(\.id)
        if allSelected(items.filter { !$0.inUse }) { usable.forEach { selected.remove($0) } } else { usable.forEach { selected.insert($0) } }
    }

    private func selectSafe() {
        selected = Set(sampler.cleanItems.filter { $0.location.risk == .safe && $0.location.scope == .user && !$0.inUse }.map(\.id))
    }
}
