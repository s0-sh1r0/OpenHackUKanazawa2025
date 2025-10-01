import SwiftUI

struct TopView: View {
    @StateObject private var quizManager = QuizManager()
    
    @State var ShowFullScreenCover: Bool = true
    
    @State private var selectedCategory: QuizCategory?
    @State private var showingAddCategorySheet = false
    @State private var showingEditCategorySheet = false
    @State private var isEditing = false
    @State private var selectedCategoryIDs: Set<UUID> = []
    
    private var selectedCategoryForEdit: QuizCategory? {
        guard let id = selectedCategoryIDs.first else { return nil }
        return quizManager.categories.first { $0.id == id }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("MemorAIze")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Text("問題集を選択してください")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(quizManager.categories, id: \.id) { category in
                            if isEditing {
                                Button(action: {
                                    toggleSelection(for: category.id)
                                }) {
                                    CategoryCard(category: category)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(selectedCategoryIDs.contains(category.id) ? Color.accentColor : Color.clear, lineWidth: 4)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                NavigationLink(destination: QuizView(category: category)) {
                                    CategoryCard(category: category)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    if isEditing {
                        Button(action: deleteSelectedCategories) {
                            Text("選択した問題集を削除")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedCategoryIDs.isEmpty ? Color.gray : Color.red)
                                .cornerRadius(12)
                        }
                        .disabled(selectedCategoryIDs.isEmpty)
                        .padding(.horizontal)
                        .padding(.bottom)
                        
                        Button {
                            showingEditCategorySheet = true
                        } label: {
                            Label("問題集を編集", systemImage: "pencil.circle.fill")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedCategoryIDs.isEmpty ? Color.gray : Color.accentColor)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)

                    } else {
                        Button(action: {
                            showingAddCategorySheet = true
                        }) {
                            Label("新しい問題集を追加", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
                .navigationTitle("MemorAIze")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(isEditing ? "完了" : "編集") {
                            isEditing.toggle()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            NavigationLink(destination: SettingView()) {
                                Image(systemName: "gearshape.fill")
                            }
                            if isEditing {
                                Button("削除") {
                                    deleteSelectedCategories()
                                }
                                .disabled(selectedCategoryIDs.isEmpty)
                            }
                        }
                    }
                }
                .onChange(of: isEditing) {
                    if !isEditing {
                        selectedCategoryIDs.removeAll()
                    }
                }
                .sheet(isPresented: $showingAddCategorySheet) {
                    AddCategoryView()
                        .environmentObject(quizManager)
                }
                .sheet(isPresented: $showingEditCategorySheet) {
                    if let category = selectedCategoryForEdit {
                        EditCategoryView(category: category)
                            .environmentObject(quizManager)
                    } else {
                        Text("カテゴリを選択してください")
                            .font(.headline).padding()
                    }
                }
                .fullScreenCover(isPresented: $ShowFullScreenCover) {
                    SignInView()
                }
            }
        }
        .environmentObject(quizManager)
    }
    
    private func deleteSelectedCategories() {
        for id in selectedCategoryIDs {
            quizManager.deleteCategory(withId: id)
        }
        selectedCategoryIDs.removeAll()
        isEditing = false
    }
    
    private func toggleSelection(for id: UUID) {
        if selectedCategoryIDs.contains(id) {
            selectedCategoryIDs.remove(id)
        } else {
            selectedCategoryIDs.insert(id)
        }
    }
}

enum Route: Hashable {
    case quiz(UUID)
    case result(UUID)
}

#Preview {
    TopView()
}
