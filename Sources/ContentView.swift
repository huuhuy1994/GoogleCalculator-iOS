import SwiftUI
import Observation
import Foundation

// MARK: - Models

struct CalcHistoryItem: Identifiable, Hashable {
    let id = UUID()
    let expression: String
    let result: String
}

enum AppTheme: String, CaseIterable {
    case system = "Theo hệ thống"
    case light = "Sáng"
    case dark = "Tối"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Math Evaluator (Hỗ trợ giai thừa !, DEG/RAD, nhân ẩn 2π, 2(3))

struct GoogleMathEvaluator {
    static func evaluate(_ raw: String, isRadians: Bool) -> Double? {
        let sanitized = raw
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: ",", with: "")
        
        var tokens = tokenize(sanitized)
        guard !tokens.isEmpty else { return nil }
        tokens = insertImplicitMultiplication(tokens)
        
        var index = 0
        guard let value = parseExpression(tokens, &index, isRadians: isRadians),
              index == tokens.count,
              value.isFinite else {
            return nil
        }
        return value
    }
    
    private static func tokenize(_ str: String) -> [String] {
        var tokens: [String] = []
        var num = ""
        let chars = Array(str)
        var i = 0
        
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace { i += 1; continue }
            
            if c.isNumber || c == "." {
                num.append(c)
                i += 1
            } else if c == "π" || c == "√" {
                if !num.isEmpty { tokens.append(num); num = "" }
                tokens.append(String(c))
                i += 1
            } else if c.isLetter {
                if !num.isEmpty { tokens.append(num); num = "" }
                var word = ""
                while i < chars.count && chars[i].isLetter {
                    word.append(chars[i])
                    i += 1
                }
                tokens.append(word)
            } else {
                if !num.isEmpty { tokens.append(num); num = "" }
                tokens.append(String(c))
                i += 1
            }
        }
        if !num.isEmpty { tokens.append(num) }
        return tokens
    }
    
    private static func insertImplicitMultiplication(_ tokens: [String]) -> [String] {
        let functions: Set<String> = ["sin", "cos", "tan", "ln", "log", "√"]
        var result: [String] = []
        
        for (i, token) in tokens.enumerated() {
            if i > 0 {
                let prev = tokens[i - 1]
                let prevIsValue = Double(prev) != nil || prev == ")" || prev == "π" || prev == "e" || prev == "!" || prev == "%"
                let currStartsValue = token == "(" || token == "π" || token == "e" || functions.contains(token) || Double(token) != nil
                if prevIsValue && currStartsValue {
                    result.append("*")
                }
            }
            result.append(token)
        }
        return result
    }
    
    private static func parseExpression(_ tokens: [String], _ idx: inout Int, isRadians: Bool) -> Double? {
        guard var left = parseTerm(tokens, &idx, isRadians: isRadians) else { return nil }
        while idx < tokens.count && (tokens[idx] == "+" || tokens[idx] == "-") {
            let op = tokens[idx]; idx += 1
            guard let right = parseTerm(tokens, &idx, isRadians: isRadians) else { return nil }
            left = (op == "+") ? left + right : left - right
        }
        return left
    }
    
    private static func parseTerm(_ tokens: [String], _ idx: inout Int, isRadians: Bool) -> Double? {
        guard var left = parsePower(tokens, &idx, isRadians: isRadians) else { return nil }
        while idx < tokens.count && (tokens[idx] == "*" || tokens[idx] == "/") {
            let op = tokens[idx]; idx += 1
            guard let right = parsePower(tokens, &idx, isRadians: isRadians) else { return nil }
            if op == "/" {
                if right == 0 { return nil }
                left /= right
            } else {
                left *= right
            }
        }
        return left
    }
    
    private static func parsePower(_ tokens: [String], _ idx: inout Int, isRadians: Bool) -> Double? {
        guard var base = parseUnary(tokens, &idx, isRadians: isRadians) else { return nil }
        while idx < tokens.count && tokens[idx] == "^" {
            idx += 1
            guard let exp = parseUnary(tokens, &idx, isRadians: isRadians) else { return nil }
            base = pow(base, exp)
        }
        return base
    }
    
    private static func parseUnary(_ tokens: [String], _ idx: inout Int, isRadians: Bool) -> Double? {
        if idx < tokens.count && tokens[idx] == "-" {
            idx += 1
            guard let v = parseUnary(tokens, &idx, isRadians: isRadians) else { return nil }
            return -v
        }
        if idx < tokens.count && tokens[idx] == "+" {
            idx += 1
            return parseUnary(tokens, &idx, isRadians: isRadians)
        }
        guard var val = parsePrimary(tokens, &idx, isRadians: isRadians) else { return nil }
        
        while idx < tokens.count && (tokens[idx] == "%" || tokens[idx] == "!") {
            if tokens[idx] == "%" {
                idx += 1
                val /= 100.0
            } else if tokens[idx] == "!" {
                idx += 1
                guard val >= 0, val <= 170, floor(val) == val else { return nil }
                val = factorial(Int(val))
            }
        }
        return val
    }
    
    private static func parsePrimary(_ tokens: [String], _ idx: inout Int, isRadians: Bool) -> Double? {
        guard idx < tokens.count else { return nil }
        let token = tokens[idx]
        
        if let num = Double(token) { idx += 1; return num }
        if token == "π" { idx += 1; return Double.pi }
        if token == "e" { idx += 1; return M_E }
        
        if token == "(" {
            idx += 1
            guard let val = parseExpression(tokens, &idx, isRadians: isRadians) else { return nil }
            if idx < tokens.count && tokens[idx] == ")" { idx += 1 }
            return val
        }
        
        let funcs: Set<String> = ["sin", "cos", "tan", "ln", "log", "√"]
        if funcs.contains(token) {
            idx += 1
            guard let arg = parseUnary(tokens, &idx, isRadians: isRadians) else { return nil }
            let angle = isRadians ? arg : (arg * .pi / 180.0)
            switch token {
            case "sin": return sin(angle)
            case "cos": return cos(angle)
            case "tan": return tan(angle)
            case "ln":  return arg > 0 ? log(arg) : nil
            case "log": return arg > 0 ? log10(arg) : nil
            case "√":   return arg >= 0 ? sqrt(arg) : nil
            default: return nil
            }
        }
        return nil
    }
    
    private static func factorial(_ n: Int) -> Double {
        if n <= 1 { return 1 }
        return (2...n).reduce(1.0) { $0 * Double($1) }
    }
}

// MARK: - ViewModel

@Observable
class GoogleCalcViewModel {
    var expression: String = ""
    var isRadians: Bool = false
    var isScientificExpanded: Bool = false
    var isResultFinal: Bool = false
    var errorMessage: String? = nil
    var history: [CalcHistoryItem] = []
    var theme: AppTheme = .system
    var hapticTrigger: Int = 0
    
    var livePreview: String {
        guard !expression.isEmpty, !isResultFinal else { return "" }
        let balanced = autoCloseParentheses(expression)
        guard let value = GoogleMathEvaluator.evaluate(balanced, isRadians: isRadians) else {
            return ""
        }
        let formatted = formatNumber(value)
        return formatted == expression ? "" : formatted
    }
    
    func append(_ token: String) {
        hapticTrigger += 1
        errorMessage = nil
        let operators = ["+", "−", "×", "÷", "^"]
        
        if isResultFinal {
            isResultFinal = false
            if !operators.contains(token) && token != "%" && token != "!" {
                expression = ""
            }
        }
        
        if operators.contains(token) {
            if expression.isEmpty {
                if token == "−" { expression = "−" }
                return
            }
            if let last = expression.last, operators.contains(String(last)) {
                expression.removeLast()
            }
        }
        
        expression += token
    }
    
    func appendFunction(_ fn: String) {
        hapticTrigger += 1
        errorMessage = nil
        if isResultFinal {
            isResultFinal = false
            expression = ""
        }
        expression += "\(fn)("
    }
    
    func appendSmartParenthesis() {
        hapticTrigger += 1
        errorMessage = nil
        if isResultFinal {
            isResultFinal = false
            expression = "("
            return
        }
        let openCount = expression.filter { $0 == "(" }.count
        let closeCount = expression.filter { $0 == ")" }.count
        let closableSuffix: Set<Character> = ["0","1","2","3","4","5","6","7","8","9",")","π","e","!","%"]
        
        if openCount > closeCount, let last = expression.last, closableSuffix.contains(last) {
            expression += ")"
        } else {
            expression += "("
        }
    }
    
    func backspace() {
        hapticTrigger += 1
        errorMessage = nil
        if isResultFinal {
            isResultFinal = false
        }
        guard !expression.isEmpty else { return }
        
        for fn in ["sin(", "cos(", "tan(", "log(", "ln("] {
            if expression.hasSuffix(fn) {
                expression.removeLast(fn.count)
                return
            }
        }
        expression.removeLast()
    }
    
    func clearAll() {
        hapticTrigger += 1
        expression = ""
        errorMessage = nil
        isResultFinal = false
    }
    
    func evaluate() {
        hapticTrigger += 1
        guard !expression.isEmpty else { return }
        let balanced = autoCloseParentheses(expression)
        
        guard let value = GoogleMathEvaluator.evaluate(balanced, isRadians: isRadians) else {
            errorMessage = "Lỗi định dạng"
            return
        }
        
        let formatted = formatNumber(value)
        if balanced != formatted {
            history.insert(CalcHistoryItem(expression: balanced, result: formatted), at: 0)
        }
        expression = formatted
        isResultFinal = true
        errorMessage = nil
    }
    
    func restore(_ item: CalcHistoryItem) {
        hapticTrigger += 1
        expression = item.result
        isResultFinal = false
        errorMessage = nil
    }
    
    private func autoCloseParentheses(_ expr: String) -> String {
        let open = expr.filter { $0 == "(" }.count
        let close = expr.filter { $0 == ")" }.count
        return expr + String(repeating: ")", count: max(0, open - close))
    }
    
    private func formatNumber(_ value: Double) -> String {
        if abs(value) >= 1e12 || (abs(value) > 0 && abs(value) < 1e-8) {
            return String(format: "%.6g", value)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Material 3 Color Palette

struct M3Colors {
    let scheme: ColorScheme
    
    var background: Color {
        scheme == .dark ? Color(red: 0.08, green: 0.09, blue: 0.11) : Color(red: 0.98, green: 0.98, blue: 1.0)
    }
    var displaySurface: Color {
        scheme == .dark ? Color(red: 0.15, green: 0.17, blue: 0.21) : Color(red: 0.91, green: 0.94, blue: 0.99)
    }
    var numberButton: Color {
        scheme == .dark ? Color(red: 0.13, green: 0.15, blue: 0.18) : Color(red: 0.94, green: 0.96, blue: 0.99)
    }
    var operatorButton: Color {
        scheme == .dark ? Color(red: 0.22, green: 0.27, blue: 0.36) : Color(red: 0.77, green: 0.86, blue: 0.99)
    }
    var acButton: Color {
        scheme == .dark ? Color(red: 0.23, green: 0.31, blue: 0.25) : Color(red: 0.76, green: 0.93, blue: 0.82)
    }
    var equalsButton: Color {
        scheme == .dark ? Color(red: 0.18, green: 0.34, blue: 0.56) : Color(red: 0.67, green: 0.80, blue: 1.0)
    }
    var primaryText: Color {
        scheme == .dark ? Color(red: 0.90, green: 0.92, blue: 0.96) : Color(red: 0.10, green: 0.12, blue: 0.16)
    }
    var secondaryText: Color {
        scheme == .dark ? Color(red: 0.65, green: 0.70, blue: 0.78) : Color(red: 0.35, green: 0.40, blue: 0.48)
    }
}

// MARK: - Main View

struct ContentView: View {
    @Environment(\.colorScheme) private var systemScheme
    @State private var vm = GoogleCalcViewModel()
    @State private var showHistory = false
    
    private var colors: M3Colors {
        M3Colors(scheme: vm.theme.colorScheme ?? systemScheme)
    }
    
    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            
            VStack(spacing: 12) {
                displayCard
                scientificSection
                mainKeypad
            }
            .padding(.bottom, 12)
        }
        .preferredColorScheme(vm.theme.colorScheme)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: vm.hapticTrigger)
        .sheet(isPresented: $showHistory) {
            GoogleHistorySheet(vm: vm, isPresented: $showHistory)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var displayCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text(vm.isRadians ? "RAD" : "DEG")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colors.secondaryText)
                    .padding(.leading, 8)
                
                Spacer()
                
                Menu {
                    Button {
                        showHistory = true
                    } label: {
                        Label("Lịch sử", systemImage: "clock.arrow.circlepath")
                    }
                    
                    Menu {
                        Picker("Giao diện", selection: $vm.theme) {
                            ForEach(AppTheme.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                    } label: {
                        Label("Chọn giao diện", systemImage: "paintbrush")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.title3)
                        .foregroundStyle(colors.primaryText)
                        .frame(width: 40, height: 40)
                }
            }
            
            Spacer(minLength: 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(vm.expression.isEmpty ? "0" : vm.expression)
                    .font(.system(size: vm.isScientificExpanded ? 44 : 58, weight: .regular, design: .rounded))
                    .foregroundStyle(vm.expression.isEmpty ? colors.secondaryText : colors.primaryText)
            }
            .defaultScrollAnchor(.trailing)
            
            HStack {
                Spacer()
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.red)
                } else {
                    Text(vm.livePreview.isEmpty ? " " : vm.livePreview)
                        .font(.system(size: 30, weight: .regular, design: .rounded))
                        .foregroundStyle(colors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            
            Capsule()
                .fill(colors.secondaryText.opacity(0.45))
                .frame(width: 36, height: 4)
                .padding(.top, 4)
                .onTapGesture { showHistory = true }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28,
                topTrailingRadius: 0
            )
            .fill(colors.displaySurface)
            .ignoresSafeArea(edges: .top)
        )
    }
    
    private var scientificSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                sciButton("√") { vm.append("√") }
                sciButton("π") { vm.append("π") }
                sciButton("^") { vm.append("^") }
                sciButton("!") { vm.append("!") }
                
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        vm.isScientificExpanded.toggle()
                    }
                } label: {
                    Image(systemName: vm.isScientificExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.bold())
                        .foregroundStyle(colors.primaryText)
                        .frame(width: 36, height: 36)
                        .background(colors.numberButton, in: Circle())
                }
            }
            
            if vm.isScientificExpanded {
                HStack(spacing: 10) {
                    sciButton(vm.isRadians ? "DEG" : "RAD") { vm.isRadians.toggle() }
                    sciButton("sin") { vm.appendFunction("sin") }
                    sciButton("cos") { vm.appendFunction("cos") }
                    sciButton("tan") { vm.appendFunction("tan") }
                }
                HStack(spacing: 10) {
                    sciButton("e") { vm.append("e") }
                    sciButton("ln") { vm.appendFunction("ln") }
                    sciButton("log") { vm.appendFunction("log") }
                    sciButton("1/x") { vm.append("^(-1)") }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func sciButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(colors.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
        }
    }
    
    private var mainKeypad: some View {
        let spacing: CGFloat = 10
        let btnHeight: CGFloat = vm.isScientificExpanded ? 58 : 74
        
        return VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                m3Button("AC", bg: colors.acButton, height: btnHeight) { vm.clearAll() }
                m3Button("( )", bg: colors.operatorButton, height: btnHeight) { vm.appendSmartParenthesis() }
                m3Button("%", bg: colors.operatorButton, height: btnHeight) { vm.append("%") }
                m3Button("÷", bg: colors.operatorButton, height: btnHeight) { vm.append("÷") }
            }
            HStack(spacing: spacing) {
                m3Button("7", bg: colors.numberButton, height: btnHeight) { vm.append("7") }
                m3Button("8", bg: colors.numberButton, height: btnHeight) { vm.append("8") }
                m3Button("9", bg: colors.numberButton, height: btnHeight) { vm.append("9") }
                m3Button("×", bg: colors.operatorButton, height: btnHeight) { vm.append("×") }
            }
            HStack(spacing: spacing) {
                m3Button("4", bg: colors.numberButton, height: btnHeight) { vm.append("4") }
                m3Button("5", bg: colors.numberButton, height: btnHeight) { vm.append("5") }
                m3Button("6", bg: colors.numberButton, height: btnHeight) { vm.append("6") }
                m3Button("−", bg: colors.operatorButton, height: btnHeight) { vm.append("−") }
            }
            HStack(spacing: spacing) {
                m3Button("1", bg: colors.numberButton, height: btnHeight) { vm.append("1") }
                m3Button("2", bg: colors.numberButton, height: btnHeight) { vm.append("2") }
                m3Button("3", bg: colors.numberButton, height: btnHeight) { vm.append("3") }
                m3Button("+", bg: colors.operatorButton, height: btnHeight) { vm.append("+") }
            }
            HStack(spacing: spacing) {
                m3Button("0", bg: colors.numberButton, height: btnHeight) { vm.append("0") }
                m3Button(".", bg: colors.numberButton, height: btnHeight) { vm.append(".") }
                m3IconButton("delete.left", bg: colors.numberButton, height: btnHeight) { vm.backspace() }
                m3Button("=", bg: colors.equalsButton, height: btnHeight) { vm.evaluate() }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func m3Button(_ title: String, bg: Color, height: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 28, weight: .regular, design: .rounded))
                .foregroundStyle(colors.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(bg, in: Capsule())
        }
    }
    
    private func m3IconButton(_ systemName: String, bg: Color, height: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(colors.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(bg, in: Capsule())
        }
    }
}

// MARK: - History Sheet

struct GoogleHistorySheet: View {
    @Bindable var vm: GoogleCalcViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            Group {
                if vm.history.isEmpty {
                    ContentUnavailableView(
                        "Không có lịch sử",
                        systemImage: "clock",
                        description: Text("Các phép tính đã thực hiện sẽ hiển thị ở đây.")
                    )
                } else {
                    List {
                        ForEach(vm.history) { item in
                            Button {
                                vm.restore(item)
                                isPresented = false
                            } label: {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(item.expression)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                    Text(item.result)
                                        .font(.title2.weight(.medium))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .onDelete { vm.history.remove(atOffsets: $0) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Lịch sử")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !vm.history.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Xóa", role: .destructive) { vm.history.removeAll() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") { isPresented = false }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
