# GitHub Search App Example

이 예시 앱은 `swift-network` 라이브러리를 사용하여 GitHub API를 호출하고 저장소를 검색하는 SwiftUI 앱입니다.

## 기능

- 🔍 GitHub 저장소 검색
- 📱 SwiftUI 기반 모던 UI
- 🌐 Network 라이브러리를 사용한 API 호출
- 📄 무한 스크롤 (페이지네이션)
- 🔄 Pull-to-refresh
- 📊 저장소 상세 정보 표시
- 🎨 프로그래밍 언어별 색상 표시
- ⭐ 스타 수 표시

## 실행 방법

### 1. 디렉토리 이동
```bash
cd Examples/GitHubSearchApp
```

### 2. 앱 빌드 및 실행
```bash
swift run
```

### 3. iOS 시뮬레이터에서 실행
```bash
swift run --configuration release
```

## 앱 구조

```
GitHubSearchApp/
├── GitHubSearchApp.swift          # 메인 앱 파일
├── Models/
│   └── GitHubModels.swift         # GitHub API 모델
├── API/
│   ├── GitHubEndpoint.swift       # API 엔드포인트 정의
│   └── GitHubService.swift        # API 서비스 클래스
├── ViewModels/
│   └── SearchViewModel.swift      # 검색 뷰 모델
├── Views/
│   ├── SearchView.swift           # 메인 검색 뷰
│   └── RepositoryCardView.swift   # 저장소 카드 뷰
└── Package.swift                  # Swift Package 설정
```

## Network 라이브러리 사용 예시

### 1. Endpoint 정의
```swift
public enum GitHubEndpoint: Endpoint {
    case searchRepositories(query: String, page: Int = 1, perPage: Int = 20)
    
    public var baseURL: URL {
        return URL(string: "https://api.github.com")!
    }
    
    public var path: String {
        return "/search/repositories"
    }
    
    public var method: Http.Method {
        return .get
    }
    
    public var task: Http.Task {
        let parameters = [
            "q": query,
            "page": "\(page)",
            "per_page": "\(perPage)"
        ]
        return .requestParameters(parameters: parameters, encoding: .url)
    }
}
```

### 2. Network Provider 설정
```swift
public class GitHubService: ObservableObject {
    private let networkProvider: NetworkProvider<GitHubEndpoint>
    
    public init() {
        // 로깅 플러그인과 함께 Network Provider 초기화
        let loggingPlugin = LoggingPlugin(logger: ConsoleLogger(level: .info))
        self.networkProvider = NetworkProvider(plugins: [loggingPlugin])
    }
}
```

### 3. API 호출
```swift
public func searchRepositories(query: String, page: Int = 1) async throws -> GitHubSearchResponse {
    let endpoint = GitHubEndpoint.searchRepositories(query: query, page: page)
    return try await networkProvider.request(endpoint, as: GitHubSearchResponse.self)
}
```

## 주요 특징

### 1. Protocol-Oriented Design
- `Endpoint` 프로토콜을 사용한 타입 안전한 API 정의
- `NetworkProvider`를 통한 일관된 네트워킹 인터페이스

### 2. Plugin System
- `LoggingPlugin`을 사용한 요청/응답 로깅
- 확장 가능한 플러그인 아키텍처

### 3. Error Handling
- `NetworkError`를 통한 체계적인 에러 처리
- 사용자 친화적인 에러 메시지 표시

### 4. Modern Swift Features
- `async/await`를 사용한 비동기 프로그래밍
- `@MainActor`를 사용한 UI 업데이트
- SwiftUI의 `@StateObject`와 `@Published`를 활용한 반응형 UI

## 스크린샷

앱은 다음과 같은 화면들을 포함합니다:

1. **검색 화면**: 저장소 검색 입력 및 결과 목록
2. **저장소 카드**: 각 저장소의 기본 정보 표시
3. **상세 화면**: 선택된 저장소의 자세한 정보

## 요구사항

- iOS 16.0+ / macOS 13.0+
- Swift 6.0+
- Xcode 15.0+

## 라이선스

이 예시 앱은 MIT 라이선스 하에 배포됩니다.
