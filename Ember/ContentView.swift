//
//  ContentView.swift
//  Ember
//
//  Created by Marcus Win on 4/3/26.
//
import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
}

struct ContentView: View {

    @State private var messages: [Message] = [
        Message(text: "Who's on your mind?", isFromUser: false)
    ]
    @State private var inputText: String = ""
    @State private var isThinking: Bool = false

    let apiKey = Bundle.main.object(forInfoDictionaryKey: "CLAUDE_API_KEY") as? String ?? ""

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            messageList
            Divider()
            inputBar
        }
        .background(Color(red: 0.96, green: 0.95, blue: 0.93))
        .ignoresSafeArea(edges: .bottom)
    }

    var headerBar: some View {
        HStack {
            Text("ember")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.09))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                    if isThinking {
                        TypingIndicator()
                            .id("typing")
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) {
                withAnimation {
                    proxy.scrollTo("bottom")
                }
            }
            .onChange(of: isThinking) {
                withAnimation {
                    proxy.scrollTo("bottom")
                }
            }
        }
    }

    var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Say something...", text: $inputText, axis: .vertical)
                .font(.system(size: 16))
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22))

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.gray.opacity(0.4)
                            : Color(red: 0.5, green: 0.47, blue: 0.87)
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                      || isThinking)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .padding(.bottom, 20)
        .background(Color(red: 0.96, green: 0.95, blue: 0.93))
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        messages.append(Message(text: text, isFromUser: true))
        inputText = ""
        isThinking = true

        // Capture history before the async call
        let currentHistory = messages

        Task {
            let reply = await askClaude(text, history: currentHistory)
            isThinking = false
            messages.append(Message(text: reply, isFromUser: false))
        }
    }

    func askClaude(_ userMessage: String, history: [Message]) async -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 300,
            "system": """
                You are Ember, a personal relationship agent.
                You help people stay close to the people who matter most to them.
                Be warm, brief, and specific. Two sentences maximum.
                Never say 'reach out' or 'touch base'.
                When you suggest something, name it concretely.
                """,
            "messages": history.map { message in
                [
                    "role": message.isFromUser ? "user" : "assistant",
                    "content": message.text
                ]
            }
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await URLSession.shared.data(for: request)
        else {
            return "Something went wrong. Try again?"
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let first = content.first,
            let text = first["text"] as? String
        else {
            return "Something went wrong. Try again?"
        }

        return text
    }
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !message.isFromUser {
                Circle()
                    .fill(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .fill(Color(red: 0.5, green: 0.47, blue: 0.87))
                            .frame(width: 8, height: 8)
                    )
            }

            if message.isFromUser { Spacer(minLength: 60) }

            Text(message.text)
                .font(.system(size: 16))
                .foregroundColor(message.isFromUser ? .white : Color(red: 0.1, green: 0.1, blue: 0.09))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.isFromUser
                        ? Color(red: 0.5, green: 0.47, blue: 0.87)
                        : Color.white
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))

            if !message.isFromUser { Spacer(minLength: 60) }
        }
    }
}

struct TypingIndicator: View {
    @State private var animatingDot = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(Color(red: 0.5, green: 0.47, blue: 0.87).opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .fill(Color(red: 0.5, green: 0.47, blue: 0.87))
                        .frame(width: 8, height: 8)
                )

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .offset(y: animatingDot == index ? -5 : 0)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: animatingDot
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer(minLength: 60)
        }
        .onAppear {
            animatingDot = 2
        }
    }
}

#Preview {
    ContentView()
}
