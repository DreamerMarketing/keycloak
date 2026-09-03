<#import "field.ftl" as field>
<!DOCTYPE html>
<html class="${properties.kcHtmlClass!}" lang="${lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <title>${msg("loginAccountTitle")}</title>
  <link rel="icon" href="${url.resourcesPath}/img/favicon-logo1-192.png">
  <#if properties.stylesCommon?has_content>
    <#list properties.stylesCommon?split(' ') as style>
      <link href="${url.resourcesCommonPath}/${style}" rel="stylesheet">
    </#list>
  </#if>
  <#if properties.styles?has_content>
    <#list properties.styles?split(' ') as style>
      <link href="${url.resourcesPath}/${style}" rel="stylesheet">
    </#list>
  </#if>
  <script type="module" src="${url.resourcesPath}/js/passwordVisibility.js"></script>
</head>
<body class="hzt-login-page">
  <main class="login-screen">
    <header class="login-site-nav" aria-label="登录页导航">
      <div class="login-wordmark">
        <img src="${url.resourcesPath}/img/favicon-logo1-192.png" alt="">
        <span>婚字头｜获客研究院</span>
      </div>
    </header>

    <section class="login-card" aria-label="婚字头 AI 数据平台登录">
      <aside class="login-visual">
        <div class="login-copy" aria-hidden="true">
          <span class="login-kicker">IN THE FUTURE</span>
          <div class="future-mark">未来</div>
          <div class="company-line"><i></i><strong>深圳婚字头网络科技有限公司</strong><i></i></div>
          <p>七年深耕婚嫁数字营销，专注解决婚嫁中小企业线上盈利难题</p>
        </div>
        <div class="login-visual-meta" aria-label="品牌能力">
          <div><strong>7年</strong><span>婚嫁数字营销</span></div>
          <div><strong>AI</strong><span>数据经营平台</span></div>
        </div>
      </aside>

      <section class="login-form-panel">
        <div class="login-form-inner">
          <div class="mobile-brand"><img src="${url.resourcesPath}/img/logo21-full-trimmed.png" alt="婚字头"></div>
          <div class="auth-tabs" role="tablist" aria-label="登录注册切换">
            <button type="button" role="tab" class="active" aria-selected="true">登录</button>
            <#if realm.registrationAllowed && !registrationDisabled??>
              <a role="tab" aria-selected="false" href="${url.registrationUrl}">注册</a>
            <#else>
              <span role="tab" aria-selected="false" aria-disabled="true">注册</span>
            </#if>
          </div>
          <h1>${msg("loginAccountTitle")}</h1>
          <p class="login-subtitle">请使用账号或邮箱进入婚字头 AI 数据平台</p>

          <#if message?has_content>
            <div class="login-alert login-alert-${message.type}" role="alert">${kcSanitize(message.summary)?no_esc}</div>
          </#if>

          <form id="kc-form-login" class="login-form" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post" novalidate="novalidate">
            <#if !usernameHidden??>
              <div class="login-field">
                <label for="username">${msg("usernameOrEmail")}</label>
                <div class="login-field-control <#if messagesPerField.existsError('username','password')>has-error</#if>">
                  <i class="fas fa-user" aria-hidden="true"></i>
                  <input id="username" name="username" type="text" value="${(login.username!'')}" autocomplete="username" aria-invalid="<#if messagesPerField.existsError('username','password')>true<#else>false</#if>">
                </div>
                <#if messagesPerField.existsError('username','password')>
                  <p class="field-error">${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}</p>
                </#if>
              </div>
            </#if>

            <div class="login-field password-field">
              <label for="password">${msg("password")}</label>
              <div class="login-field-control">
                <i class="fas fa-lock" aria-hidden="true"></i>
                <input id="password" name="password" type="password" autocomplete="current-password" <#if usernameHidden??>autofocus</#if>>
                <button class="password-toggle" type="button" aria-label="${msg('showPassword')}" aria-controls="password" data-password-toggle data-icon-show="fa-eye fas" data-icon-hide="fa-eye-slash fas" data-label-show="${msg('showPassword')}" data-label-hide="${msg('hidePassword')}" id="password-show-password">
                  <i class="fa-eye fas" aria-hidden="true"></i>
                </button>
              </div>
            </div>

            <div class="login-row">
              <#if realm.rememberMe && !usernameHidden??>
                <label class="remember-control" for="rememberMe">
                  <input id="rememberMe" name="rememberMe" type="checkbox" checked>
                  <span>${msg("rememberMe")}</span>
                </label>
              <#else><span></span></#if>
              <#if realm.resetPasswordAllowed>
                <a class="forgot-link" href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a>
              </#if>
            </div>

            <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>>
            <button id="kc-login" name="login" class="login-submit" type="submit">
              <span>${msg("doLogIn")}</span><i class="fas fa-arrow-right" aria-hidden="true"></i>
            </button>
            <#if realm.registrationAllowed && !registrationDisabled??>
              <a class="login-mode-switch" href="${url.registrationUrl}">使用企业邮箱注册</a>
            </#if>
          </form>
          <footer class="login-footer">© 2026 婚字头 AI 数据平台，保留所有权利。</footer>
        </div>
      </section>
    </section>
  </main>
</body>
</html>
