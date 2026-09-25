#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
palet_oneri.py — ÖNERİLEN PREMIUM PALETİ ÖLÇER (12 Eylül).
Adayları ölçer, hiçbirini uygulamaz.
"""
import os, sys, math
KOK = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, KOK)
from renk_korluk_check import benzet, lab, dE, _dogrusal
from tema_oku import hex_rgb

def dg(h):            # hex → dogrusal rgb
    return tuple(_dogrusal(x) for x in hex_rgb(h))
def Y(h):
    r,g,b = dg(h); return 0.2126*r + 0.7152*g + 0.0722*b
def kont(f, b):
    a,c = Y(f), Y(b); hi,lo = max(a,c), min(a,c)
    return (hi+0.05)/(lo+0.05)
def LCh(h):
    Ls,a,bb = lab(dg(h))
    return Ls, math.hypot(a,bb), (math.degrees(math.atan2(bb,a))+360)%360
def uzerine(ust, al, alt):
    u,a = hex_rgb(ust), hex_rgb(alt)
    return "#%02X%02X%02X" % tuple(round(u[i]*al + a[i]*(1-al)) for i in range(3))
def dEh(h1, h2):      # iki hex arası ΔE76
    return dE(dg(h1), dg(h2))
def benzet_hex(h, tur):
    r,g,b = benzet(h, tur)     # dogrusal 0..1
    def gg(c):
        c = 12.92*c if c <= 0.0031308 else 1.055*(c**(1/2.4))-0.055
        return max(0, min(255, round(c*255)))
    return "#%02X%02X%02X" % (gg(r), gg(g), gg(b))

BG = "#100E12"
print("="*100)
print("1 · ALTIN — mevcut vs şampanya/bronz adayları")
print("="*100)
ALTIN = [("MEVCUT gold","#D1B56D"),("MEVCUT goldBtn","#EBCD92"),("MEVCUT goldText","#E0BE7A"),
         ("Şampanya A","#D8C9AC"),("Şampanya B","#C9B693"),("Şampanya C","#BFAC8A"),
         ("Mat Bronz A","#B39A72"),("Mat Bronz B","#A78C63"),("Antik Pirinç","#9C8257")]
print("%-18s %-9s %6s %6s %7s %10s %14s" % ("","HEX","L*","C*","hue°","#100E12'de","koyu mürekkep"))
for ad,h in ALTIN:
    Ls,C,H = LCh(h)
    km = kont("#171310", h)
    print("%-18s %-9s %6.1f %6.1f %7.1f %9.2f:1 %10.2f:1 %s" % (ad,h,Ls,C,H,kont(h,BG),km,"✓" if km>=4.5 else "✗"))

print()
print("="*100)
print("2 · ZEMİN — mevcut vs obsidyen rampası   (ink #F6F1E8)")
print("="*100)
ZEMIN = [("MEVCUT bg","#100E12"),("MEVCUT surface","#1C1820"),("MEVCUT bgAlt","#241F28"),("MEVCUT line","#262222"),
         ("Obsidyen bg","#0B0A0B"),("Obsidyen yüzey","#141211"),("Obsidyen yüzey2","#1B1816"),("Obsidyen tel","#262220")]
for ad,h in ZEMIN:
    Ls,C,H = LCh(h)
    print("%-17s %-9s L*=%5.2f C*=%5.2f hue=%6.1f  ink %6.2f:1  body #D9D1C6 %6.2f:1" %
          (ad,h,Ls,C,H,kont("#F6F1E8",h),kont("#D9D1C6",h)))
print("\n   Katman ayrımı ΔE76  (<1.5 ayırt edilemez · 2–6 sezilir · >8 kaba)")
for a,b in [("#100E12","#1C1820"),("#1C1820","#241F28"),("#241F28","#262222"),
            ("#0B0A0B","#141211"),("#141211","#1B1816"),("#1B1816","#262220")]:
    print("     %s → %s   ΔE=%5.2f" % (a,b,dEh(a,b)))

print()
print("="*100)
print("3 · NEON'UN YERİ — durum renkleri (zemin #0B0A0B)")
print("="*100)
NEON = [("MEVCUT teal","#12CDBC"),("MEVCUT ok","#6FD9A8"),("Fildişi","#EDE7DB"),
        ("Mat zümrüt A","#8FB79B"),("Mat zümrüt B","#7FA88C"),("Mat zümrüt C","#6F9A7E"),
        ("MEVCUT amber","#FAA542"),("Mat kehribar","#D9A45E"),
        ("MEVCUT red","#F2605D"),("Mat gül","#D98079"),("Küllü gül","#C97E76")]
for ad,h in NEON:
    Ls,C,H = LCh(h)
    print("%-15s %-9s L*=%5.1f C*=%5.1f hue=%6.1f  zeminde %6.2f:1  %s" %
          (ad,h,Ls,C,H,kont(h,"#0B0A0B"),"AA ✓" if kont(h,"#0B0A0B")>=4.5 else "AA ✗"))

print()
print("="*100)
print("4 · KARAR ÜÇLÜSÜ RENK KÖRÜ GÖZDE AYRIŞIYOR MU? (eşik ΔE ≥ 25)")
print("="*100)
SETLER = {"BUGÜN (ok/cost/block)":("#6FD9A8","#FAA542","#F2605D"),
          "ÖNERİ A fildişi/kehribar/gül":("#EDE7DB","#D9A45E","#D98079"),
          "ÖNERİ B zümrüt/kehribar/küllügül":("#7FA88C","#D9A45E","#C97E76"),
          "ÖNERİ C fildişi/kehribar/küllügül":("#EDE7DB","#D9A45E","#C97E76")}
for ad,(o,c,b) in SETLER.items():
    print("\n  " + ad)
    for tur in ("normal","dötanopi","protanopi"):
        f = (lambda h: h) if tur=="normal" else (lambda h: benzet_hex(h,tur))
        ciftler = [("ok","cost",o,c),("ok","block",o,b),("cost","block",c,b)]
        vals=[]; enaz=1e9
        for n1,n2,h1,h2 in ciftler:
            d = dEh(f(h1), f(h2)); vals.append("%s↔%s %5.1f"%(n1,n2,d)); enaz=min(enaz,d)
        print("    %-10s %s  → en düşük %5.1f %s" % (tur," · ".join(vals),enaz,"✓" if enaz>=25 else "✗"))

print()
print("="*100)
print("5 · FOTOĞRAFIN ÜSTÜNDE BUZLU CAM — gerçek render'da ölçülen en parlak bant pikseli #6B4A38")
print("="*100)
for al in (0.40,0.50,0.55,0.62,0.70):
    z = uzerine("#141211", al, "#6B4A38")
    print("  rgba(20,18,17,%.2f) → %s   ink %5.2f · body %5.2f · mutedAA %5.2f · dim %5.2f" %
          (al,z,kont("#F6F1E8",z),kont("#D9D1C6",z),kont("#A79B8A",z),kont("#918677",z)))
