# JitPack 发布指南

这个仓库通过 JitPack 发布已经编译好的 Android GPL full AAR。对外依赖坐标是：

```gradle
implementation 'com.github.TooWhiteT:ffmpeg-kit-16k:<tag>'
```

示例：

```gradle
implementation 'com.github.TooWhiteT:ffmpeg-kit-16k:gpl-full-1.0'
```

不要使用类似下面这种多模块坐标：

```gradle
implementation 'com.github.TooWhiteT.ffmpeg-kit-16k:ffmpeg-kit-gpl-full:<tag>'
```

JitPack 当前会把这个仓库作为单项目 artifact 发布，所以正确的 `groupId` 是 `com.github.TooWhiteT`，
`artifactId` 是 `ffmpeg-kit-16k`。

## 发布检查清单

1. 本地编译新的 GPL full AAR。

   当前目标是 Android NDK 28、GPL full、排除 x86 架构：

   ```bash
   ./android.sh --enable-gpl --full --disable-lib-gnutls --disable-x86 --disable-x86-64
   ```

2. 替换要发布的 AAR 文件。

   文件路径必须保持为：

   ```text
   prebuilt/bundle-android-aar/ffmpeg-kit/ffmpeg-kit-gpl-full.aar
   ```

   根目录的 `build.gradle` 会发布这个文件。如果以后路径变了，也要同步修改 `build.gradle` 里的 `aarFile`。

3. 检查 ABI 内容。

   这个包应该包含 `arm64-v8a` 和 `armeabi-v7a`，不应该包含 `x86` 或 `x86_64`：

   ```bash
   unzip -l prebuilt/bundle-android-aar/ffmpeg-kit/ffmpeg-kit-gpl-full.aar | rg 'jni/(arm64-v8a|armeabi-v7a|x86|x86_64)/'
   ```

4. 检查 64 位 so 的 16 KB ELF page alignment。

   使用 NDK 28 的 `llvm-readelf`：

   ```bash
   TMP=$(mktemp -d)
   unzip -q prebuilt/bundle-android-aar/ffmpeg-kit/ffmpeg-kit-gpl-full.aar 'jni/**/*.so' -d "$TMP"
   find "$TMP/jni/arm64-v8a" -name '*.so' | sort | while read -r file; do
     align=$("$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf" -l "$file" | awk '/LOAD/ {print $NF}' | sort -u | tr '\n' ',' | sed 's/,$//')
     printf '%s %s\n' "${file#$TMP/}" "$align"
   done
   ```

   `arm64-v8a` 下所有 so 的期望值都是 `0x4000`。

   注意：NDK 预编译的 `armeabi-v7a/libc++_shared.so` 可能是 `0x1000`。Google Play 的 16 KB native library
   要求重点是 64 位设备，所以发布前最重要的是确认所有 `arm64-v8a` so 都是 `0x4000`。

5. 本地验证 Maven 发布。

   ```bash
   ./android/gradlew -p . publishToMavenLocal
   ```

   检查本地 Maven 产物是否生成：

   ```bash
   ls -lh ~/.m2/repository/com/github/TooWhiteT/ffmpeg-kit-16k/local-SNAPSHOT/
   ```

   生成的 POM 应该是：

   ```text
   groupId: com.github.TooWhiteT
   artifactId: ffmpeg-kit-16k
   packaging: aar
   ```

6. 提交并推送 AAR 更新。

   ```bash
   git add prebuilt/bundle-android-aar/ffmpeg-kit/ffmpeg-kit-gpl-full.aar build.gradle README.md JITPACK_RELEASE.md
   git commit -m "Release GPL full AAR <version>"
   git push
   ```

7. 创建新 tag。

   每次发布新的 AAR 都应该创建新 tag。不要复用 `gpl-full-1.0`，因为 JitPack 会按 tag 缓存构建产物。

   推荐 tag 命名：

   ```text
   gpl-full-1.1
   gpl-full-1.2
   gpl-full-2.0
   ```

   命令示例：

   ```bash
   git tag -a gpl-full-1.1 -m "Release GPL full 16K AAR 1.1"
   git push fork gpl-full-1.1
   ```

8. 触发 JitPack 构建。

   打开：

   ```text
   https://jitpack.io/#TooWhiteT/ffmpeg-kit-16k/<tag>
   ```

   例如：

   ```text
   https://jitpack.io/#TooWhiteT/ffmpeg-kit-16k/gpl-full-1.1
   ```

9. 验证 JitPack 上的 POM 和 AAR。

   把 `<tag>` 替换成新版本 tag：

   ```bash
   curl -L -s -o /tmp/ffmpeg-kit-16k.pom -w "%{http_code} %{size_download}\n" \
     https://jitpack.io/com/github/TooWhiteT/ffmpeg-kit-16k/<tag>/ffmpeg-kit-16k-<tag>.pom

   curl -L -s -o /tmp/ffmpeg-kit-16k.aar -w "%{http_code} %{size_download}\n" \
     https://jitpack.io/com/github/TooWhiteT/ffmpeg-kit-16k/<tag>/ffmpeg-kit-16k-<tag>.aar
   ```

   两个请求都应该返回 HTTP `200`。AAR 文件大小不能是 0，并且应该接近本地 AAR 的大小。

## 注意事项

- tag 就是发布版本号。优先创建新 tag，不要移动或覆盖已有 tag。
- GitHub 会对超过 50 MB 的文件提示警告。当前 AAR 大约 57 MB，高于推荐值，但低于 GitHub 100 MB 硬限制。
- 不要轻易把 AAR 改成 Git LFS 管理，除非重新验证过 JitPack 发布流程。直接把 AAR 放在仓库里更简单稳定。
- 保留 POM 里的 `smart-exception-java` 依赖。FFmpegKit 的 Java API 会用到它。
- 这是 GPL artifact。依赖它的 App 需要遵守 GPL 义务和 AAR 内打包的第三方许可证。
