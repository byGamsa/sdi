import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "SDI Exercises",
  description: "Step-by-Step Anleitungen für die Übungen der Vorlesung Software Defined Infrastructure an der HdM Stuttgart",
  base: '/sdi/',
  themeConfig: {
    search: {
      provider: 'local',
    },

    nav: [
      { text: 'Home', link: '/' },
      { text: 'Übungen', link: '/exercises/' },
      { text: 'Themen', link: '/topics/' },
    ],

    sidebar: {
      '/exercises/': [
        {
          text: 'Übungen',
          items: [
            { text: 'Übersicht', link: '/exercises/' },
          ],
        },
        {
          text: 'Terraform',
          collapsed: false,
          items: [
            { text: 'Exercise 13', link: '/exercises/13-incrementally-creating-a-base-system' },
            { text: 'Exercise 14', link: '/exercises/14-cloud-init' },
            { text: 'Exercise 15', link: '/exercises/15-working-on-cloud-init' },
            { text: 'Exercise 16', link: '/exercises/16-solving-the-known-hosts-quirk' },
            { text: 'Exercise 17', link: '/exercises/17-generating-host-meta-data' },
            { text: 'Exercise 18', link: '/exercises/18-a-module-for-ssh-host-key-handling' },
            { text: 'Exercise 19', link: '/exercises/19-partitions-and-mounting' },
            { text: 'Exercise 20', link: '/exercises/20-mounts-points-name-specification' },
            { text: 'Exercise 21', link: '/exercises/21-enhancing-your-web-server' },
            { text: 'Exercise 22', link: '/exercises/22-creating-dns-records' },
            { text: 'Exercise 23', link: '/exercises/23-creating-host-with-corresponding-dns-entries' },
            { text: 'Exercise 24', link: '/exercises/24-creating-a-fixed-number-of-servers' },
          ],
        },
      ],
      '/topics/': [
        {
          text: 'Themen',
          items: [
            { text: 'Übersicht', link: '/topics/' },
            { text: 'Einführung', link: '/topics/introduction' },
          ],
        },
        {
          text: 'Manual Server Management',
          collapsed: false,
          items: [
            { text: 'Hetzner Cloud GUI', link: '/topics/hetzner-cloud-gui' },
            { text: 'SSH verwenden', link: '/topics/using-ssh' },
          ],
        },
        {
          text: 'Cloud Provider',
          collapsed: false,
          items: [
            { text: 'Arbeiten mit Terraform', link: '/topics/working-with-terraform' },
            { text: 'Cloud-init', link: '/topics/cloud-init' },
            { text: 'Terraform Module', link: '/topics/terraform-modules' },
            { text: 'Volumes', link: '/topics/volumes' },
            { text: 'Terraform Loops', link: '/topics/terraform-loops' },
            { text: 'Terraform und DNS', link: '/topics/terraform-and-dns' },
            { text: 'SSL Zertifikate', link: '/topics/ssl-certificates' },
            { text: 'Terraform States', link: '/topics/terraform-states' },
          ],
        },
        {
          text: 'Netzwerk',
          collapsed: false,
          items: [
            { text: 'Private Netzwerke', link: '/topics/private-networks' },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/byGamsa/sdi' }
    ],

    footer: {
      message: 'Released under the <a href="https://github.com/vuejs/vitepress/blob/main/LICENSE">MIT License</a>.',
      copyright: 'Copyright © 2025 <a href="https://larsgerigk.de">Lars Gerigk</a>'
    }
  }
})
