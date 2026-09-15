# Crest

iOS native skeleton for BlackWave/Crest.

- UI: SwiftUI
- Auth: `POST https://blackwave.org.cn/yuanji/api/v1/auth/login`
- Token storage: Keychain
- Current scope: login -> chat shell

## Simulator sync

Use the signed sync script so the simulator build keeps the Keychain application identifier:

```sh
./scripts/sync-simulator.sh
```

Do not build the app with `CODE_SIGNING_ALLOWED=NO`. The script verifies
`RZA2NW5788.com.blackwave.crest` before installing the app.
