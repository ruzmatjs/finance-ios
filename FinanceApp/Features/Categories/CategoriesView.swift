import SwiftUI
import SwiftData

/// Kategoriyalar — daromad/xarajat segmenti, qoʻshish/tahrirlash/oʻchirish, sevimli.
struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @State private var kind: CategoryKind = .expense
    @State private var editing: Category?
    @State private var showAdd = false

    private var filtered: [Category] { categories.filter { $0.kind == kind } }
    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tur", selection: $kind) {
                Text("Xarajat").tag(CategoryKind.expense)
                Text("Daromad").tag(CategoryKind.income)
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.lg) {
                    ForEach(filtered) { cat in
                        VStack(spacing: 8) {
                            CategoryIconView(symbol: cat.symbol, color: cat.color, size: 56)
                                .overlay(alignment: .topTrailing) {
                                    if cat.isFavorite {
                                        Image(systemName: "star.fill").font(.caption2)
                                            .foregroundStyle(.yellow).padding(4)
                                    }
                                }
                            Text(cat.name).font(.caption).lineLimit(1)
                        }
                        .onTapGesture { editing = cat }
                        .contextMenu {
                            Button { toggleFav(cat) } label: {
                                Label(cat.isFavorite ? "Sevimlidan olib tashlash" : "Sevimli",
                                      systemImage: "star")
                            }
                            if !cat.isDefault {
                                Button(role: .destructive) { delete(cat) } label: {
                                    Label("Oʻchirish", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Kategoriyalar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { CategoryEditorView(kind: kind) }
        .sheet(item: $editing) { CategoryEditorView(category: $0) }
    }

    private func toggleFav(_ c: Category) { c.isFavorite.toggle(); try? context.save() }
    private func delete(_ c: Category) { context.delete(c); try? context.save() }
}

/// Kategoriya qoʻshish/tahrirlash — ikonka va rang tanlash bilan.
struct CategoryEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let existing: Category?
    @State private var name = ""
    @State private var kind: CategoryKind
    @State private var symbol = "tag.fill"
    @State private var colorHex = "#0A84FF"

    init(category: Category? = nil, kind: CategoryKind = .expense) {
        self.existing = category
        _kind = State(initialValue: category?.kind ?? kind)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        CategoryIconView(symbol: symbol, color: Color(hex: colorHex), size: 72)
                        Spacer()
                    }.listRowBackground(Color.clear)
                }
                Section("Nomi") { TextField("Kategoriya nomi", text: $name) }
                Section("Ikonka") { SymbolPicker(selection: $symbol) }
                Section("Rang") { ColorPalettePicker(selection: $colorHex) }
            }
            .navigationTitle(existing == nil ? "Yangi kategoriya" : "Tahrirlash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Bekor") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Saqlash") { save() }.disabled(name.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let c = existing else { return }
        name = c.name; symbol = c.symbol; colorHex = c.colorHex; kind = c.kind
    }

    private func save() {
        if let c = existing {
            c.name = name; c.symbol = symbol; c.colorHex = colorHex; c.kindRaw = kind.rawValue
        } else {
            context.insert(Category(name: name, kind: kind, symbol: symbol,
                                    colorHex: colorHex, sortIndex: 99))
        }
        try? context.save()
        dismiss()
    }
}
