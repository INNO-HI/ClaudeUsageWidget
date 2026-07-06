import SwiftUI

// MARK: - Buddy Egg View (off / hatching states)

struct BuddyEggView: View {
    let state: BuddyState
    @State private var animPhase: CGFloat = 0

    var body: some View {
        ZStack {
            if state == .off {
                VStack(spacing: 6) {
                    Text("  _____\n /     \\\n|  ???  |\n \\_____/")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary.opacity(0.4))
                        .multilineTextAlignment(.center)
                    Text(L.hatchPrompt)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                Text("  _____\n /     \\\n| *  * |\n \\_____/")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange)
                    .multilineTextAlignment(.center)
                    .rotationEffect(.degrees(animPhase))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.15).repeatCount(10, autoreverses: true)) {
                            animPhase = 5
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Rarity Color Helper

func rarityColor(_ rarity: BuddyRarity) -> Color {
    switch rarity {
    case .common:    return Color.gray
    case .uncommon:  return Color(hex: 0x10B981)
    case .rare:      return Color(hex: 0x3B82F6)
    case .epic:      return Color(hex: 0x8B5CF6)
    case .legendary: return Color(hex: 0xF59E0B)
    }
}

// MARK: - ASCII Art Species

func asciiArt(for species: BuddySpecies, eyes: String, hat: BuddyHat) -> String {
    let e = eyes
    let hatLine: String = {
        switch hat {
        case .none:      return ""
        case .crown:     return "  \\|/\n"
        case .tophat:    return "  ___\n  |_|\n"
        case .propeller: return "  -+- \n"
        case .halo:      return "  ooo\n"
        case .wizard:    return "  /\\\n / \\\n"
        case .beanie:    return "  .-.\n"
        case .tinyduck:  return "  >o)\n"
        }
    }()

    let body: String = {
        switch species {
        case .cat:
            return " /\\_/\\\n( \(e) \(e) )\n > ^ <"
        case .rabbit:
            return " (\\(\\  \n ( \(e)\(e) )\n o(\")(\") "
        case .duck:
            return "   __\n >(\(e)\(e))__\n  (  __)>\n   ||"
        case .dragon:
            return "  /\\_/\\_\n (  \(e) \(e) )\n  \\ ~~ /\n  /|  |\\"
        case .owl:
            return "  {o,o}\n /)___)\n  \" \""
        case .penguin:
            return "   _\n  (\(e)\(e))\n /( oo )\\\n  \" \""
        case .ghost:
            return "  .___.\n | \(e) \(e) |\n |  o  |\n  \\^^^/"
        case .octopus:
            return "   ___\n  (\(e) \(e))\n /||||||\\"
        case .turtle:
            return "     __\n  .-(\(e)\(e))\n /   ____\\\n|_\\_/____/"
        case .snail:
            return "    @  @\n  _(\(e)  \(e))_\n (________)"
        case .mushroom:
            return "  .--.\n / \(e)\(e) \\\n|------|\n  ||||"
        case .robot:
            return " [====]\n |\(e)  \(e)|\n |_--_|\n  d  b"
        case .goose:
            return "   ,\n  (\(e)>\n  / |\n _/ /"
        case .cactus:
            return "  _\n | |\n/|\(e)|\\\n | |\n |_|"
        case .axolotl:
            return " \\(\(e) \(e))/\n  (  u  )\n  /| | |\\"
        case .blob:
            return "  .oOo.\n ( \(e) \(e) )\n  `oOo'"
        case .capybara:
            return "  ____\n (\(e)  \(e))\n (    )\n /|  |\\"
        case .chonk:
            return " /\\_/\\\n( \(e) \(e) )\n(  >o< )\n (     )"
        }
    }()

    return hatLine + body
}

// MARK: - Full Buddy Card View (ASCII Art)

struct BuddyCardView: View {
    let spec: BuddySpec
    let state: BuddyState
    let mood: Int
    let bonusStats: [Int]
    let canFeed: Bool
    let onPet: () -> Void
    let onFeed: () -> Void
    let onSleep: () -> Void

    @State private var animPhase: CGFloat = 0
    @State private var shinyPhase: Double = 0

    var body: some View {
        VStack(spacing: 10) {
            buddyAsciiSection
            buddyInfoSection
            buddyStatsSection
            buddyControlsSection
        }
        .onChange(of: state) { _ in
            animPhase = 0
        }
    }

    // MARK: - ASCII Avatar

    private var buddyAsciiSection: some View {
        ZStack {
            if spec.isShiny {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.yellow.opacity(0.15 + 0.1 * sin(shinyPhase)),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 60
                        )
                    )
                    .frame(height: 90)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            shinyPhase = .pi
                        }
                    }
            }

            VStack(spacing: 0) {
                asciiAnimated
                    .frame(height: 80)

                Text("~~~~~~~~")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Theme.textSecondary.opacity(0.2))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(spec.name) — \(spec.species.displayName), \(spec.rarity.displayName)")

            if state == .happy {
                Text("*")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange)
                    .offset(x: -50, y: -20)
                Text("<3")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.danger)
                    .offset(x: 50, y: -25)
            }

            if state == .working {
                Text("[...]")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                    .offset(x: 50, y: -20)
            }

            if state == .sleepy {
                Text("z Z z")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
                    .offset(x: 45, y: -25)
            }

            if spec.isShiny {
                Text("*")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.yellow)
                    .offset(x: -55, y: -30)
                Text("*")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.yellow)
                    .offset(x: 55, y: -10)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var asciiAnimated: some View {
        let art = asciiArt(for: spec.species, eyes: spec.eyes, hat: spec.hat)
        return Group {
            switch state {
            case .idle:
                Text(art)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange)
                    .multilineTextAlignment(.center)
                    .offset(y: animPhase)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            animPhase = -3
                        }
                    }
            case .happy:
                Text(art)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange)
                    .multilineTextAlignment(.center)
                    .offset(y: animPhase)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true)) {
                            animPhase = -6
                        }
                    }
            case .working:
                Text(art)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .offset(x: animPhase)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                            animPhase = 2
                        }
                    }
            case .sleepy:
                Text(art)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .rotationEffect(.degrees(animPhase))
                    .onAppear {
                        withAnimation(.easeIn(duration: 1.0)) {
                            animPhase = -10
                        }
                    }
            default:
                Text(art)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.claudeOrange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Info

    private var buddyInfoSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if spec.isShiny {
                    Text("*")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
                Text(spec.name)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                if spec.isShiny {
                    Text("*")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
            }

            HStack(spacing: 6) {
                Text(spec.species.displayName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)

                Text("[\(spec.eyes)]")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)

                Text(spec.rarity.displayName)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(rarityColor(spec.rarity))
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - Stats (ASCII bar)

    private var buddyStatsSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(0..<5) { i in
                BuddyStatBar(
                    name: BuddyStats.statNames[i],
                    value: spec.stats.asArray[i],
                    bonus: bonusStats[i],
                    rarity: spec.rarity
                )
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Controls

    private var buddyControlsSection: some View {
        VStack(spacing: 6) {
            Text(String(repeating: "<3 ", count: mood) + String(repeating: ".. ", count: 5 - mood))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Theme.danger)
                .accessibilityLabel(L.buddyMood(mood))

            Text(buddyTip)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Theme.textSecondary.opacity(0.6))
                .multilineTextAlignment(.center)

            if state == .idle || state == .happy {
                HStack(spacing: 6) {
                    Button(action: onPet) {
                        Text("/buddy pet")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.claudeOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Theme.claudeOrange.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Theme.claudeOrange.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L.petBuddy)

                    Button(action: onFeed) {
                        Text("/buddy feed")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(canFeed ? Theme.success : Theme.textSecondary.opacity(0.4))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(canFeed ? Theme.success.opacity(0.1) : Theme.textSecondary.opacity(0.04))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(canFeed ? Theme.success.opacity(0.3) : Theme.border.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canFeed)
                    .accessibilityLabel(L.feedBuddy)

                    Button(action: onSleep) {
                        Text("/buddy off")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Theme.textSecondary.opacity(0.08))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var buddyTip: String {
        switch L.lang {
        case .ko:
            if mood == 0 { return "!! 배고파요... 능력치가 떨어지고 있어요" }
            if mood < 2 { return "tip: 밥 주면 능력치가 올라가요 (하루 1회)" }
            if !canFeed { return "tip: 오늘 밥은 먹었어요. 내일 또 주세요~" }
            if state == .happy { return "냠냠! 맛있다~ 고마워요!" }
            return "tip: /buddy feed 로 밥을 주세요"
        case .ja:
            if mood == 0 { return "!! お腹空いた... ステータスが下がっています" }
            if mood < 2 { return "tip: ご飯をあげるとステータスが上がります (1日1回)" }
            if !canFeed { return "tip: 今日は食べました。明日もお願いします~" }
            if state == .happy { return "もぐもぐ! 美味しい~ ありがとう!" }
            return "tip: /buddy feed でご飯をあげてください"
        case .zhCN:
            if mood == 0 { return "!! 饿了... 属性正在下降" }
            if mood < 2 { return "tip: 喂食可提升属性 (每日 1 次)" }
            if !canFeed { return "tip: 今天已经喂过了,明天再来~" }
            if state == .happy { return "好吃! 谢谢你!" }
            return "tip: /buddy feed 来喂食"
        case .en:
            if mood == 0 { return "!! hungry... stats are dropping" }
            if mood < 2 { return "tip: feed me to boost stats (1x/day)" }
            if !canFeed { return "tip: already fed today. come back tomorrow~" }
            if state == .happy { return "yum! delicious~ thank you!" }
            return "tip: /buddy feed to boost a random stat"
        }
    }
}

// MARK: - Buddy Stat Bar (Graph)

struct BuddyStatBar: View {
    let name: String
    let value: Int
    let bonus: Int
    let rarity: BuddyRarity

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 58, alignment: .trailing)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Theme.progressBg.opacity(0.4))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(rarityColor(rarity).opacity(0.8))
                        .frame(
                            width: max(3, geometry.size.width * CGFloat(min(value + bonus, 15)) / 15.0),
                            height: 6
                        )

                    if bonus > 0 {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Theme.success.opacity(0.9))
                            .frame(
                                width: max(3, geometry.size.width * CGFloat(bonus) / 15.0),
                                height: 6
                            )
                            .offset(x: geometry.size.width * CGFloat(value) / 15.0)
                    }
                }
            }
            .frame(height: 6)

            HStack(spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                if bonus > 0 {
                    Text("+\(bonus)")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.success)
                }
            }
            .frame(width: 30, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(bonus > 0 ? "\(value)+\(bonus)" : "\(value)")
    }
}
