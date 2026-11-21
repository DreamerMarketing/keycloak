const brandAssetBase = "https://data.hztcloud.cn/data-platform/brand-assets/";
const platform = "矩阵智联 AI 数据平台";

async function loadSiteBrand() {
  const response = await fetch("/data-platform-site-brand", {
    cache: "no-store",
    credentials: "omit",
    signal: AbortSignal.timeout(2500)
  });
  if (!response.ok) return;
  const { brand } = await response.json();
  if (brand !== "matrix") return;

  document.body.dataset.siteBrand = brand;
  document.title = `${platform}｜${document.title}`;

  const wordmark = document.querySelector(".login-wordmark span");
  if (wordmark) wordmark.textContent = "矩阵智联获客研究院";
  const icon = document.querySelector(".login-wordmark img");
  if (icon) icon.src = new URL("matrix-logo.jpg", brandAssetBase).href;
  const favicon = document.querySelector('link[rel="icon"]');
  if (favicon) favicon.href = new URL("matrix-logo.jpg", brandAssetBase).href;
  const mobileLogo = document.querySelector(".mobile-brand img");
  if (mobileLogo) {
    mobileLogo.src = new URL("matrix-sidebar-logo.png", brandAssetBase).href;
    mobileLogo.alt = "矩阵智联获客研究院";
  }

  const card = document.querySelector(".login-card");
  const label = card?.getAttribute("aria-label");
  if (label) card.setAttribute("aria-label", label.replace("婚字头 AI 数据平台", platform));

  const company = document.querySelector(".company-line strong");
  if (company) company.textContent = "矩阵智联获客研究院";
  const subtitle = document.querySelector(".login-subtitle");
  if (subtitle) subtitle.textContent = subtitle.textContent.replace("婚字头 AI 数据平台", platform);
  const footer = document.querySelector(".login-footer");
  if (footer) footer.textContent = footer.textContent.replace("婚字头 AI 数据平台", platform);
}

void loadSiteBrand().catch(() => {});
