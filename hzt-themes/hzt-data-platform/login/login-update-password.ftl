<#import "password-validation.ftl" as validator>
<!DOCTYPE html>
<html class="${properties.kcHtmlClass!}" lang="${lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <title>${msg("updatePasswordTitle")}</title>
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
<body class="hzt-login-page hzt-password-page">
  <main class="login-screen">
    <header class="login-site-nav" aria-label="登录页导航">
      <div class="login-wordmark">
        <img src="${url.resourcesPath}/img/favicon-logo1-192.png" alt="">
        <span>婚字头｜获客研究院</span>
      </div>
    </header>

    <section class="login-card" aria-label="婚字头 AI 数据平台修改密码">
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
          <h1>${msg("updatePasswordTitle")}</h1>
          <p class="login-subtitle">${msg("hztUpdatePasswordSubtitle")}</p>

          <#if message?has_content>
            <div class="login-alert login-alert-${message.type}" role="alert">${kcSanitize(message.summary)?no_esc}</div>
          </#if>

          <form id="kc-passwd-update-form" class="login-form" action="${url.loginAction}" method="post">
            <#list [{"name": "password-new", "error": "password", "label": "passwordNew"}, {"name": "password-confirm", "error": "password-confirm", "label": "passwordConfirm"}] as input>
              <div class="login-field password-field">
                <label for="${input.name}">${msg(input.label)}</label>
                <div class="login-field-control <#if messagesPerField.existsError(input.error)>has-error</#if>">
                  <i class="fas fa-lock" aria-hidden="true"></i>
                  <input id="${input.name}" name="${input.name}" type="password" autocomplete="new-password" required <#if input?index == 0>autofocus</#if> aria-invalid="${messagesPerField.existsError(input.error)?c}" aria-describedby="input-error-container-${input.name}">
                  <button class="password-toggle" type="button" aria-label="${msg('showPassword')}" aria-controls="${input.name}" data-password-toggle data-icon-show="fa-eye fas" data-icon-hide="fa-eye-slash fas" data-label-show="${msg('showPassword')}" data-label-hide="${msg('hidePassword')}">
                    <i class="fa-eye fas" aria-hidden="true"></i>
                  </button>
                </div>
                <div id="input-error-container-${input.name}" class="field-error" aria-live="polite">
                  <#if messagesPerField.existsError(input.error)>
                    <p class="field-error">${kcSanitize(messagesPerField.get(input.error))?no_esc}</p>
                  </#if>
                </div>
              </div>
            </#list>

            <div class="login-row">
              <label class="remember-control" for="logout-sessions">
                <input id="logout-sessions" name="logout-sessions" type="checkbox" value="on">
                <span>${msg("logoutOtherSessions")}</span>
              </label>
            </div>
            <button id="kc-submit" name="login" class="login-submit" type="submit">
              <span>${msg("doSubmit")}</span><i class="fas fa-arrow-right" aria-hidden="true"></i>
            </button>
            <#if isAppInitiatedAction??>
              <button id="kc-cancel" class="login-mode-switch password-cancel" type="submit" name="cancel-aia" value="true" formnovalidate>${msg("doCancel")}</button>
            </#if>
          </form>
          <@validator.templates/>
          <@validator.script field="password-new"/>
          <footer class="login-footer">© 2026 婚字头 AI 数据平台，保留所有权利。</footer>
        </div>
      </section>
    </section>
  </main>
</body>
</html>
