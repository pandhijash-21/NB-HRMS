// NB Platform Documentation Client JS
document.addEventListener("DOMContentLoaded", () => {
  // 1. Highlight active navigation item
  const currentPath = window.location.pathname.split("/").pop() || "index.html";
  const navLinks = document.querySelectorAll(".sidebar-nav-item a");
  navLinks.forEach((link) => {
    const href = link.getAttribute("href");
    if (href === currentPath || (currentPath === "" && href === "index.html")) {
      link.closest(".sidebar-nav-item")?.classList.add("active");
    }
  });

  // 2. Mobile sidebar toggle
  const toggleBtn = document.querySelector(".mobile-toggle");
  const sidebar = document.querySelector(".docs-sidebar");
  if (toggleBtn && sidebar) {
    toggleBtn.addEventListener("click", () => {
      sidebar.classList.toggle("open");
    });
    // Close on clicking outside
    document.addEventListener("click", (e) => {
      if (!sidebar.contains(e.target) && !toggleBtn.contains(e.target) && sidebar.classList.contains("open")) {
        sidebar.classList.remove("open");
      }
    });
  }

  // 3. Code copy button functionality
  const codeBlocks = document.querySelectorAll("pre code");
  codeBlocks.forEach((codeBlock) => {
    const pre = codeBlock.parentElement;
    if (!pre.previousElementSibling || !pre.previousElementSibling.classList.contains("code-header")) {
      const header = document.createElement("div");
      header.className = "code-header";
      header.innerHTML = `<span>Source Code</span><button class="copy-btn">Copy</button>`;
      pre.parentNode.insertBefore(header, pre);
      const copyBtn = header.querySelector(".copy-btn");
      copyBtn.addEventListener("click", () => copyCode(codeBlock, copyBtn));
    }
  });

  document.querySelectorAll(".copy-btn").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      const header = e.target.closest(".code-header");
      if (header && header.nextElementSibling && header.nextElementSibling.tagName === "PRE") {
        const code = header.nextElementSibling.querySelector("code");
        if (code) copyCode(code, e.target);
      }
    });
  });

  function copyCode(codeElement, buttonElement) {
    const text = codeElement.innerText;
    navigator.clipboard.writeText(text).then(() => {
      const orig = buttonElement.innerText;
      buttonElement.innerText = "Copied!";
      buttonElement.style.color = "#10b981";
      setTimeout(() => {
        buttonElement.innerText = orig;
        buttonElement.style.color = "";
      }, 2000);
    });
  }

  // 4. In-page filter / search
  const searchInput = document.querySelector("#docSearch");
  if (searchInput) {
    searchInput.addEventListener("input", (e) => {
      const term = e.target.value.toLowerCase().trim();
      const contentSections = document.querySelectorAll("section[id], .feature-card, tr, .diagram-box");
      if (!term) {
        contentSections.forEach((el) => (el.style.display = ""));
        return;
      }
      contentSections.forEach((el) => {
        const text = el.innerText.toLowerCase();
        if (text.includes(term)) {
          el.style.display = "";
        } else {
          // If it is a major section containing matching children, don't hide it
          if (el.tagName === "SECTION" && el.querySelector(`*:not(h2):not(h3)`)) {
            // keep visible if children match
          } else {
            el.style.display = "none";
          }
        }
      });
    });
  }
});
