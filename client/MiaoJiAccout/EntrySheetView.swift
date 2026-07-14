import SwiftUI
import UIKit

enum EntrySheet: Identifiable, Hashable { case voice, manual, edit(ExpenseRecord); var id: String { switch self { case .voice: "voice"; case .manual: "manual"; case .edit(let record): record.id.uuidString } } }

struct ActionCard: View {
    let icon: String, title: String, text: String, colors: [Color]
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 10) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).frame(width: 42, height: 42).background(.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 14))
                Text(title).font(.system(size: 16, weight: .bold))
                Text(text).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.78)).multilineTextAlignment(.center)
            }.foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 122, alignment: .center).padding(16)
                .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08)))
        }.buttonStyle(.plain)
    }
}

struct ProgressLine: View {
    let title: String, value: Double
    var body: some View {
        VStack(spacing: 6) {
            HStack { Text(title); Spacer(); Text("\(Int(value * 100))%") }.font(.system(size: 12)).foregroundStyle(Palette.muted)
            GeometryReader { geo in
                Capsule().fill(Palette.line).overlay(alignment: .leading) {
                    Capsule().fill(LinearGradient(colors: [Palette.primary, Palette.accent], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * min(max(value, 0), 1))
                }
            }.frame(height: 10)
        }
    }
}

struct EntrySheetView: View {
    @EnvironmentObject private var store: AppStore
    let type: EntrySheet
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceInput = MiaoJiInputService()
    @State private var amount: String
    @State private var title: String
    @State private var note: String
    @State private var categoryID: UUID?
    @State private var date: Date
    @State private var recordType: RecordType
    @State private var showsDateEditor = false
    @State private var voiceDrafts: [VoiceExpenseDraft] = []
    @State private var showsCategoryManager = false
    @FocusState private var focusedField: EntryField?

    private enum EntryField: Hashable { case amount, title, note }
    init(type: EntrySheet) {
        self.type = type
        if case .edit(let record) = type {
            _amount = State(initialValue: String(format: "%.2f", record.amount)); _title = State(initialValue: record.title); _note = State(initialValue: record.note); _categoryID = State(initialValue: record.categoryID); _date = State(initialValue: record.date); _recordType = State(initialValue: record.recordType)
        } else {
            _amount = State(initialValue: ""); _title = State(initialValue: ""); _note = State(initialValue: ""); _categoryID = State(initialValue: nil); _date = State(initialValue: .now); _recordType = State(initialValue: .expense)
        }
    }
    private var isVoice: Bool { if case .voice = type { true } else { false } }
    private var editingRecord: ExpenseRecord? { if case .edit(let record) = type { record } else { nil } }
    private var sheetTitle: String {
        if isVoice { return "语音记账" }
        return editingRecord == nil ? "添加\(recordType.rawValue)" : "编辑\(recordType.rawValue)"
    }
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .background(Color.black.opacity(0.2))
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sheetTitle).font(.title3.bold())
                        Text(
                            isVoice
                                ? "说出金额和用途，AI 会自动识别并整理记账明细。"
                                : "保留完整金额、分类、时间和备注字段。"
                        )
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                    }
                    Spacer(); Button("关闭") { voiceInput.cancelRecording(); dismiss() }.buttonStyle(SoftButtonStyle())
                }
                if isVoice && voiceDrafts.isEmpty {
                    GlassCard {
                        VStack(spacing: 16) {
                            if voiceInput.isUploading || voiceInput.isAnalyzing {
                                AIParsingAnimation()
                            } else {
                                Badge(text: voiceInput.isRecording ? "录" : "语", color: voiceInput.isRecording ? .pink : .cyan, size: 84)
                                    .scaleEffect(voiceInput.isRecording ? 1.08 : 1)
                                    .animation(
                                        voiceInput.isRecording
                                            ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                                            : .default,
                                        value: voiceInput.isRecording
                                    )
                            }
                            Text(voiceInput.statusMessage)
                                .font(.caption)
                                .foregroundStyle(voiceInput.isRecording ? Palette.pink : voiceInput.isAnalyzing ? Palette.primary : Palette.muted)
                                .multilineTextAlignment(.center)
                            Text("示例：午餐 45 元，打车 28 元，买水果 16.5 元")
                                .font(.caption)
                                .foregroundStyle(Palette.muted)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    Button {
                        if voiceInput.isRecording {
                            Task {
                                do {
                                    let token = try await store.voiceAuthorizationToken()
                                    await voiceInput.stopRecording(
                                        categories: store.categories,
                                        authorizationToken: token
                                    )
                                } catch {
                                    voiceInput.cancelRecording()
                                    voiceInput.showAuthorizationFailure(error)
                                }
                            }
                        } else {
                            guard store.isCloudSignedIn else {
                                voiceInput.showAccountRequired()
                                return
                            }
                            Task { await voiceInput.startRecording() }
                        }
                    } label: {
                        Label(
                            voiceInput.isUploading
                                ? "正在上传"
                                : voiceInput.isAnalyzing ? "AI 解析中"
                                : voiceInput.isRecording ? "停止录音" : "开始录音",
                            systemImage: voiceInput.isUploading
                                ? "arrow.up.circle.fill"
                                : voiceInput.isAnalyzing ? "sparkles"
                                : voiceInput.isRecording ? "stop.fill" : "mic.fill"
                        )
                    }
                    .buttonStyle(GradientButtonStyle())
                    .disabled(voiceInput.isBusy)
                    .opacity(voiceInput.isBusy ? 0.6 : 1)

                    if voiceInput.canRetry {
                        Button(voiceInput.uploadedAudioPath == nil ? "重新上传并解析" : "重新进行 AI 解析") {
                            Task {
                                do {
                                    let token = try await store.voiceAuthorizationToken()
                                    await voiceInput.retry(
                                        categories: store.categories,
                                        authorizationToken: token
                                    )
                                } catch {
                                    voiceInput.showAuthorizationFailure(error)
                                }
                            }
                        }
                        .buttonStyle(SoftButtonStyle(fullWidth: true))
                    }
                } else if isVoice {
                    VoiceDraftEditor(
                        drafts: $voiceDrafts,
                        onManageCategories: { showsCategoryManager = true }
                    )
                    HStack(spacing: 12) {
                        Button("重新录音") {
                            voiceDrafts = []
                            Task { await voiceInput.startRecording() }
                        }
                        .buttonStyle(SoftButtonStyle(fullWidth: true))
                        Button("统一保存", action: saveVoiceDrafts)
                            .buttonStyle(GradientButtonStyle())
                            .disabled(!canSaveVoiceDrafts)
                            .opacity(canSaveVoiceDrafts ? 1 : 0.55)
                    }
                } else {
                    Picker("类型", selection: $recordType) {
                        ForEach(RecordType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DarkField(label: "金额", placeholder: "0.00", text: $amount, keyboard: .decimalPad)
                        .focused($focusedField, equals: .amount)
                    DarkField(
                        label: "标题",
                        placeholder: recordType == .expense ? "例如：午餐 / 咖啡 / 打车" : "例如：工资 / 奖金 / 退款",
                        text: $title
                    )
                        .focused($focusedField, equals: .title)
                    CategoryGridPicker(selection: $categoryID)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("时间").font(.caption).foregroundStyle(Palette.muted)
                        Button { showsDateEditor = true } label: {
                            HStack {
                                Text(Self.dateTimeFormatter.string(from: date)).foregroundStyle(Palette.text)
                                Spacer()
                                Image(systemName: "calendar.badge.clock").foregroundStyle(Palette.muted)
                            }.contentShape(Rectangle())
                        }
                            .buttonStyle(.plain).padding(.horizontal, 13).frame(height: 48)
                            .background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
                    }
                    DarkTextEditor(label: "备注", placeholder: "可选：商户、地点或付款方式", text: $note)
                        .focused($focusedField, equals: .note)
                    HStack(spacing: 12) {
                        Button("取消") { dismiss() }.buttonStyle(SoftButtonStyle(fullWidth: true))
                        Button("保存", action: save).buttonStyle(GradientButtonStyle())
                            .disabled(!canSave).opacity(canSave ? 1 : 0.55)
                    }
                }
                    }
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(Palette.line))
                    .shadow(color: .black.opacity(0.35), radius: 30, y: 16)
                    .frame(maxWidth: 430)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 24)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .ignoresSafeArea(.keyboard)
        .presentationBackground(.clear)
        .onAppear {
            if editingRecord == nil, categoryID == nil {
                categoryID = store.categories.first?.id
            }
        }
        .onDisappear { voiceInput.cancelRecording() }
        .onChange(of: voiceInput.parsedExpenses) { _, expenses in
            guard !expenses.isEmpty else { return }
            let now = Date.now
            voiceDrafts = expenses.map {
                VoiceExpenseDraft(
                    amount: $0.amount.formatted(.number.precision(.fractionLength(0...2))),
                    title: $0.title,
                    categoryID: $0.categoryID,
                    date: now
                )
            }
        }
        .sheet(isPresented: $showsDateEditor) { DateTimeEditor(date: $date) }
        .sheet(isPresented: $showsCategoryManager) { CategoryManagementView() }
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private var canSave: Bool {
        guard let value = Double(amount), value > 0 else { return false }
        guard let categoryID, store.category(for: categoryID) != nil else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSaveVoiceDrafts: Bool {
        !voiceDrafts.isEmpty && voiceDrafts.allSatisfy {
            guard let value = Double($0.amount), value > 0 else { return false }
            guard let categoryID = $0.categoryID, store.category(for: categoryID) != nil else { return false }
            return !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func saveVoiceDrafts() {
        guard canSaveVoiceDrafts else { return }
        let records = voiceDrafts.compactMap { draft -> ExpenseRecord? in
            guard let amount = Double(draft.amount), let categoryID = draft.categoryID else { return nil }
            return ExpenseRecord(
                amount: amount,
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                note: "AI 语音解析",
                categoryID: categoryID,
                date: draft.date,
                type: .expense
            )
        }
        store.records.append(contentsOf: records)
        dismiss()
    }

    private func save() {
        guard canSave, let value = Double(amount), let categoryID else { return }
        if let editingRecord, let index = store.records.firstIndex(where: { $0.id == editingRecord.id }) {
            store.records[index] = ExpenseRecord(id: editingRecord.id, amount: value, title: title, note: note, categoryID: categoryID, date: date, type: recordType)
        } else {
            store.records.append(ExpenseRecord(amount: value, title: title, note: note, categoryID: categoryID, date: date, type: recordType))
        }
        dismiss()
    }
}

struct VoiceExpenseDraft: Identifiable, Equatable {
    let id = UUID()
    var amount: String
    var title: String
    var categoryID: UUID?
    var date: Date
}

struct AIParsingAnimation: View {
    @State private var spins = false
    @State private var pulses = false

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Palette.primary.opacity(0.22), Palette.pink.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 92, height: 92)
                .scaleEffect(pulses ? 1.08 : 0.9)
            Circle()
                .trim(from: 0.08, to: 0.78)
                .stroke(
                    AngularGradient(colors: [Palette.primary, Palette.accent, Palette.pink, Palette.primary], center: .center),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 86, height: 86)
                .rotationEffect(.degrees(spins ? 360 : 0))
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [Palette.primary, Palette.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .frame(height: 100)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { spins = true }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulses = true }
        }
        .accessibilityLabel("AI 正在解析")
    }
}

struct CategoryGridPicker: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selection: UUID?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类").font(.caption).foregroundStyle(Palette.muted)
            if store.categories.isEmpty {
                Text("暂无分类，请先在设置中添加分类。")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .softRow()
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(store.categories) { category in
                        let selected = selection == category.id
                        Button { selection = category.id } label: {
                            VStack(spacing: 7) {
                                ZStack(alignment: .topTrailing) {
                                    Circle()
                                        .fill(LinearGradient(colors: BadgeColor.from(category.colorIndex).colors.map { $0.opacity(selected ? 0.95 : 0.2) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: category.icon)
                                        .font(.system(size: 19, weight: .semibold))
                                        .foregroundStyle(selected ? .white : BadgeColor.from(category.colorIndex).colors[0])
                                        .frame(width: 48, height: 48)
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.white, Palette.success)
                                            .offset(x: 4, y: -3)
                                    }
                                }
                                Text(category.name)
                                    .font(.system(size: 12, weight: selected ? .bold : .medium))
                                    .foregroundStyle(Palette.text)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selected ? Palette.primary.opacity(0.1) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Palette.primary.opacity(0.6) : Color.clear, lineWidth: 1.5))
                            .scaleEffect(selected ? 1 : 0.97)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct VoiceDraftEditor: View {
    @EnvironmentObject private var store: AppStore
    @Binding var drafts: [VoiceExpenseDraft]
    let onManageCategories: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI 已拆分 \(drafts.count) 笔明细").font(.system(size: 15, weight: .bold))
                    Text("逐条核对金额、标题、分类和时间后统一保存。").font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.success)
            }
            .softRow()

            ForEach($drafts) { $draft in
                GlassCard(padding: 14) {
                    VStack(spacing: 13) {
                        HStack {
                            Label("第 \((drafts.firstIndex(where: { $0.id == draft.id }) ?? 0) + 1) 笔", systemImage: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Palette.primary)
                            Spacer()
                            if drafts.count > 1 {
                                Button(role: .destructive) {
                                    drafts.removeAll { $0.id == draft.id }
                                } label: { Image(systemName: "trash") }
                                .buttonStyle(.plain)
                            }
                        }
                        HStack(spacing: 10) {
                            DarkField(label: "金额", placeholder: "0.00", text: $draft.amount, keyboard: .decimalPad)
                                .frame(width: 116)
                            DarkField(label: "标题", placeholder: "消费标题", text: $draft.title)
                        }
                        CategoryStripPicker(selection: $draft.categoryID, onManage: onManageCategories)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("时间").font(.caption).foregroundStyle(Palette.muted)
                            DatePicker("", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}

struct CategoryStripPicker: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selection: UUID?
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("分类").font(.caption).foregroundStyle(Palette.muted)
                Spacer()
                Button("管理", action: onManage).font(.caption.weight(.semibold)).buttonStyle(.plain).foregroundStyle(Palette.primary)
            }
            GeometryReader { proxy in
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Color.clear
                                .frame(width: max((proxy.size.width / 2) - 8, 0), height: 1)
                            ForEach(store.categories) { category in
                                let selected = selection == category.id
                                Button {
                                    selection = category.id
                                } label: {
                                    Label(category.name, systemImage: category.icon)
                                        .font(.system(size: 12, weight: selected ? .bold : .medium))
                                        .foregroundStyle(selected ? .white : Palette.text)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 10)
                                        .background(selected ? BadgeColor.from(category.colorIndex).colors[0] : Palette.soft)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(selected ? Color.clear : Palette.line))
                                }
                                .buttonStyle(.plain)
                                .id(category.id)
                            }
                            Color.clear
                                .frame(width: max((proxy.size.width / 2) - 8, 0), height: 1)
                        }
                        .frame(minWidth: proxy.size.width, alignment: .center)
                    }
                    .onAppear { centerSelection(using: scrollProxy, animated: false) }
                    .onChange(of: selection) { _, _ in centerSelection(using: scrollProxy, animated: true) }
                    .onChange(of: store.categories.map(\.id)) { _, _ in centerSelection(using: scrollProxy, animated: false) }
                }
            }
            .frame(height: 42)
        }
    }

    private func centerSelection(using proxy: ScrollViewProxy, animated: Bool) {
        guard let selection else { return }
        let action = { proxy.scrollTo(selection, anchor: .center) }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.22), action)
            } else {
                action()
            }
        }
    }
}

struct DateTimeEditor: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss
    private let calendar = Calendar.current

    private var hour: Binding<Int> { componentBinding(.hour) }
    private var minute: Binding<Int> { componentBinding(.minute) }
    private var second: Binding<Int> { componentBinding(.second) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker("日期", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                HStack(spacing: 8) {
                    timeColumn("时", selection: hour, range: 0..<24)
                    Text(":").font(.title2.bold()).padding(.top, 8)
                    timeColumn("分", selection: minute, range: 0..<60)
                    Text(":").font(.title2.bold()).padding(.top, 8)
                    timeColumn("秒", selection: second, range: 0..<60)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .navigationTitle("选择日期和时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func timeColumn(_ title: String, selection: Binding<Int>, range: Range<Int>) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(Palette.muted)
            Picker(title, selection: selection) {
                ForEach(range, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity, maxHeight: 120).clipped()
        }
    }

    private func componentBinding(_ component: Calendar.Component) -> Binding<Int> {
        Binding(
            get: { calendar.component(component, from: date) },
            set: { value in
                if let updated = calendar.date(bySetting: component, value: value, of: date) { date = updated }
            }
        )
    }
}

struct RecordRow: View {
    @EnvironmentObject private var store: AppStore
    let record: ExpenseRecord
    var showsFullDate = false
    var body: some View {
        let category = store.category(for: record.categoryID)
        ExpenseRow(badge: String(category?.name.prefix(1) ?? "?"), color: record.recordType == .income ? .green : BadgeColor.from(category?.colorIndex ?? 0), title: record.title, meta: "\(store.formatDate(record.date, dateStyle: showsFullDate ? .short : .none, timeStyle: .short)) · \(record.recordType.rawValue) · \(category?.name ?? "未分类")", amount: (record.recordType == .income ? "+" : "") + store.format(record.amount), note: record.note.isEmpty ? "本地" : record.note)
    }
}

struct DarkField: View {
    let label: String, placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption).foregroundStyle(Palette.muted)
            TextField(placeholder, text: $text).keyboardType(keyboard).padding(13).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
        }
    }
}

struct DarkTextEditor: View {
    let label: String, placeholder: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption).foregroundStyle(Palette.muted)
            ZStack(alignment: .topLeading) {
                if text.isEmpty { Text(placeholder).foregroundStyle(Palette.muted).padding(.horizontal, 4).padding(.vertical, 8).allowsHitTesting(false) }
                TextEditor(text: $text).scrollContentBackground(.hidden).frame(minHeight: 72, maxHeight: 72)
            }
            .padding(.horizontal, 9).padding(.vertical, 5).background(Palette.soft)
            .clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
        }
    }
}
