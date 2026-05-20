# craneTests

Unit test sources for link validation and streak math. Add a **Unit Testing Bundle** target named `craneTests` in Xcode (File → New → Target → Unit Testing Bundle), point it at this folder, and link `@testable import crane`.

```bash
xcodebuild -scheme craneTests -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```
