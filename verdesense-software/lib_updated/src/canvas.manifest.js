export const manifest = {
  screens: {
    scr_mz5xap: { name: "Splash", route: "/splash", position: { "x": 160, "y": 4180 } },
    scr_vphg22: { name: "Onboarding", route: "/onboarding", position: { "x": 1560, "y": 4180 } },
    scr_rs9v8e: { name: "Login", route: "/login", position: { "x": 160, "y": 8140 } },
    scr_ioh4h4: { name: "Dashboard", route: "/", position: { "x": 160, "y": 220 } },
    scr_omhflt: { name: "Map", route: "/map", position: { "x": 1560, "y": 220 } },
    scr_tkkf35: { name: "Devices", route: "/devices", position: { "x": 5760, "y": 220 } },
    scr_duf58v: { name: "Profile", route: "/profile", position: { "x": 160, "y": 2200 } },
    scr_suh8f2: { name: "Analytics", route: "/analytics", position: { "x": 7160, "y": 220 } },
    scr_h7l4lg: { name: "Logs", route: "/logs", position: { "x": 2960, "y": 220 } },
    scr_0kthgc: { name: "Settings", route: "/settings", position: { "x": 4360, "y": 220 } },
    scr_t9g3o6: { name: "Edit Profile", route: "/edit-profile", position: { "x": 1560, "y": 2200 } },
    scr_hzp81b: { name: "User Management", route: "/user-management", position: { "x": 0, "y": 0 }, isDefaultRow: true },
    scr_b6gtup: { name: "Forget Password", route: "/forgot-password", position: { "x": 160, "y": 6160 } }
  },
  sections: {
    sec_vb09dm: { name: "Main Navigation", x: 0, y: 0, width: 8520, height: 1180 },
    sec_7wp7t0: { name: "User Profile", x: 0, y: 1980, width: 2920, height: 1180 },
    sec_hy5g0a: { name: "Onboarding", x: 0, y: 3960, width: 2920, height: 1180 },
    sec_52e19x: { name: "Password Recovery", x: 0, y: 5940, width: 1520, height: 1180 },
    sec_x70ow7: { name: "Authentication", x: 0, y: 7920, width: 1520, height: 1180 }
  },
  layers: [
  { kind: "section", id: "sec_vb09dm", children: [
    { kind: "screen", id: "scr_ioh4h4" },
    { kind: "screen", id: "scr_omhflt" },
    { kind: "screen", id: "scr_h7l4lg" },
    { kind: "screen", id: "scr_0kthgc" },
    { kind: "screen", id: "scr_tkkf35" },
    { kind: "screen", id: "scr_suh8f2" }]
  },
  { kind: "screen", id: "scr_hzp81b" },
  { kind: "section", id: "sec_7wp7t0", children: [
    { kind: "screen", id: "scr_duf58v" },
    { kind: "screen", id: "scr_t9g3o6" }]
  },
  { kind: "section", id: "sec_hy5g0a", children: [
    { kind: "screen", id: "scr_mz5xap" },
    { kind: "screen", id: "scr_vphg22" }]
  },
  { kind: "section", id: "sec_52e19x", children: [
    { kind: "screen", id: "scr_b6gtup" }]
  },
  { kind: "section", id: "sec_x70ow7", children: [
    { kind: "screen", id: "scr_rs9v8e" }]
  }]

};