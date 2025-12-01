import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "SDI Exercises",
  description: "Documentation for the exercises in the lecture 113475 Software defined Infrastructure",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Examples', link: '/markdown-examples' }
    ],

    sidebar: [
      {
        text: "Cloud Setup",
        collapsed: false,
        items: [
          { text: "Hetzner Cloud Setup", link: "/chapters/01-hetzner-cloud" },
        ],
      },
      {
        text: "SSH & Remote Access",
        collapsed: false,
        items: [
          { text: "Using SSH", link: "/chapters/02-using-ssh" },
        ],
      },
      {
        text: "Terraform",
        collapsed: false,
        items: [
          { text: "Working with Terraform", link: "/chapters/13-incrementally-creating-a-base-system" },
          { text: "Cloud-init", link: "/chapters/14-cloud-init" },
          { text: "Working on Cloud-init", link: "/chapters/15-working-on-cloud-init" },
        ],
      },
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/byGamsa/sdi' }
    ],

    footer: {
      message: 'Released under the <a href="https://github.com/vuejs/vitepress/blob/main/LICENSE">MIT License</a>.',
      copyright: 'Copyright © 2025 <a href="https://larsgerigk.de">Lars Gerigk</a>'
    }
  }
})
