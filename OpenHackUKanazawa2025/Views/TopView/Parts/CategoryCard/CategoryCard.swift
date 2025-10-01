import SwiftUI

struct CategoryCard: View {
    let category: QuizCategory
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.system(size: 40))
                .foregroundColor(.white)
            
            Text(category.name)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            HStack {
                Text("\(category.questions.count)問")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                ZStack {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 90, height: 16, alignment: .center)
                    
                    Text(category.questionType.rawValue)
                        .foregroundColor(Color(category.primaryColor))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [category.primaryColor, category.secondaryColor]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    let sample = QuizCategory(
        name: "日本史",
        iconName: "building.columns",
        primaryColor: .red,
        secondaryColor: .orange,
        questions: [
            Question(
                questions: [MultipleQuestion(
                    question: "1192年に鎌倉幕府を開いた人物は？",
                    explain: "鎌倉幕府の初代将軍。"
                )],
                answer: "源頼朝",
                category: "日本史"
            )
        ],
        questionType: .freeText
    )
    CategoryCard(category: sample)
}

#Preview("TopView") {
    TopView()
}
