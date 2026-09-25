# LOUNGELINK · SQL KURULUM SIRASI
**18 Ağustos 2026 · 240 dosya**

## NASIL KURULUR

Supabase → SQL Editor. Aşağıdaki sırayla, tek tek. Hepsi `create or replace`
kullanır; **tekrar çalıştırmak güvenlidir**.

### ⚠️ HARFLİ DOSYALAR (`024a`, `087a`)
`PRE_drop` dosyalarıdır, aynı numaralı ana dosyadan **ÖNCE** çalışır.
Liste zaten doğru sırada.

### SEED DOSYALARI (en sonda, ikisi de İSTEĞE BAĞLI)
- `SEED_KURAL_SENARYOLARI.sql` — kural motorunun 9 dalı, 18 senaryo
- `SEED2_KAYNAK_SENARYOLARI.sql` — **yeni**: aynı salon/farklı kaynak,
  çok kartlı host, DragonPass aynı-uçuş şartı, PP Prestige
Canlıda test verisi istemiyorsan ikisini de atla. Her ikisinin de en
altında yorumlu TEMİZLİK bloğu var.

---

## SIRA

  1. `001_initial_schema.sql`
  2. `002_seed_reference.sql`
  3. `003_admin_roles.sql`
  4. `004_auth_bridge.sql`
  5. `005_reference_read.sql`
  6. `006_discovery_read.sql`
  7. `007_request_engine.sql`
  8. `008_chat_sessions.sql`
  9. `009_phone_otp.sql`
 10. `010_profile_write.sql`
 11. `011_notifications.sql`
 12. `012_women_safety.sql`
 13. `013_push_tokens.sql`
 14. `014_push_trigger.sql`
 15. `015_connections.sql`
 16. `016_match_score.sql`
 17. `017_marketplace.sql`
 18. `018_subscriptions.sql`
 19. `019_admin_management.sql`
 20. `020_rbac.sql`
 21. `021_moderation_tools.sql`
 22. `022_rewards_parity.sql`
 23. `023_partner_portal.sql`
 24. `024a_PRE_drop_old_discovery.sql`  ⚠ PRE_drop
 25. `024_avatars_storage.sql`
 26. `025_role_on_signup.sql`
 27. `026a_PRE_drop.sql`  ⚠ PRE_drop
 28. `026_doc_parity_core.sql`
 29. `027_companion_chat.sql`
 30. `028_referral.sql`
 31. `029_bo_requirements.sql`
 32. `030_match_and_broadcast.sql`
 33. `031_cleanup_overloads.sql`
 34. `032_p2_flows.sql`
 35. `033a_PRE_drop.sql`  ⚠ PRE_drop
 36. `033_beta_credits_dualrole_radar.sql`
 37. `034_lounge_radar.sql`
 38. `035a_PRE_drop.sql`  ⚠ PRE_drop
 39. `035_password_flow.sql`
 40. `036a_PRE_drop.sql`  ⚠ PRE_drop
 41. `036_host_applications.sql`
 42. `037a_PRE_drop.sql`  ⚠ PRE_drop
 43. `037_admin_verifications.sql`
 44. `038_SQL_DURUM.sql`
 45. `039_DOGRULAMA.sql`
 46. `040a_PRE_drop.sql`  ⚠ PRE_drop
 47. `040_visibility_and_discovery_fix.sql`
 48. `041_staff_accounts_excluded.sql`
 49. `042_reports_and_sos.sql`
 50. `043_admin_data_cleanup.sql`
 51. `044a_PRE_drop.sql`  ⚠ PRE_drop
 52. `044_trip_purpose_and_people_fix.sql`
 53. `045_admin_edit_email_phone.sql`
 54. `046a_PRE_drop.sql`  ⚠ PRE_drop
 55. `046_trust_and_host_visibility.sql`
 56. `047a_PRE_drop.sql`  ⚠ PRE_drop
 57. `047_campaign_targets.sql`
 58. `048a_PRE_drop.sql`  ⚠ PRE_drop
 59. `048_promo_campaigns.sql`
 60. `049a_PRE_drop.sql`  ⚠ PRE_drop
 61. `049_discovery_safety_phone_delete.sql`
 62. `050a_PRE_drop.sql`  ⚠ PRE_drop
 63. `050_host_requests_flight.sql`
 64. `051_beta_visibility_reset_and_diagnoz.sql`
 65. `052_session_live_status.sql`
 66. `053_unstaff_founder_and_diag.sql`
 67. `054a_PRE_drop.sql`  ⚠ PRE_drop
 68. `054_discover_people_include_hosts.sql`
 69. `055_listing_makes_host.sql`
 70. `056_supply_demand_match_notify.sql`
 71. `057_waiting_demand_rpc.sql`
 72. `058_fix_stale_staff_roles.sql`
 73. `059a_PRE_drop.sql`  ⚠ PRE_drop
 74. `059_discover_everyone_request_gate.sql`
 75. `060_security_hardening.sql`
 76. `061_fix_respond_request_and_slots.sql`
 77. `062_fix_verify_otp.sql`
 78. `063_error_logging.sql`
 79. `064_fix_overloads_and_discovery.sql`
 80. `065_fix_create_request.sql`
 81. `066_request_status_completed.sql`
 82. `067_fix_confirm_session_enum.sql`
 83. `068_fix_rate_session.sql`
 84. `069_fix_respond_connection_cast.sql`
 85. `070a_PRE_drop.sql`  ⚠ PRE_drop
 86. `070_discover_people_trip_data.sql`
 87. `071_fix_create_availability_enum.sql`
 88. `072a_PRE_drop.sql`  ⚠ PRE_drop
 89. `072_discover_availabilities_gender_langs.sql`
 90. `073_fix_seed_login.sql`
 91. `074_host_always_visible.sql`
 92. `075a_PRE_drop.sql`  ⚠ PRE_drop
 93. `075_invitable_guests_detail.sql`
 94. `076_rewards_mvp_prices.sql`
 95. `077_session_autostart_intro_slots.sql`
 96. `078_trust_single_writer.sql`
 97. `079_email_otp_contact_verification.sql`
 98. `080_session_lifecycle.sql`
 99. `081a_PRE_drop.sql`  ⚠ PRE_drop
100. `081_pending_ratings_link.sql`
101. `082_rate_limiting.sql`
102. `083_lounge_rules_and_flight_prep.sql`
103. `084_deletion_requests.sql`
104. `085_lounge_rules_v2.sql`
105. `086a_PRE_drop.sql`  ⚠ PRE_drop
106. `086_lounge_rules_v3.sql`
107. `087a_PRE_drop.sql`  ⚠ PRE_drop
108. `087_entitlements_and_coverage.sql`
109. `088_card_catalog.sql`
110. `089_missing_columns.sql`
111. `090_rules_to_app.sql`
112. `091_flight_quota.sql`
113. `092_host_access_declaration.sql`
114. `093_reward_featured.sql`
115. `094_admin_erasure.sql`
116. `095_close_the_loop.sql`
117. `096_rule_autofill.sql`
118. `097_ajet_and_tk_detail.sql`
119. `098_full_rule_matrix.sql`
120. `099_card_networks_venue_level.sql`
121. `100_tier_fee_and_time.sql`
122. `101_sections_charter_expiry.sql`
123. `102_badge_wording.sql`
124. `103_consolidate_and_charter.sql`
125. `104_tier_rules_program_level.sql`
126. `105_fee_wording_and_business.sql`
127. `106_channel_fees_and_bank_deals.sql`
128. `107_missing_airports.sql`
129. `108_paid_guest_settlement.sql`
130. `109_pegasus_and_overloads.sql`
131. `110_family_abroad.sql`
132. `111_push_direct_expo.sql`
133. `112_blocks_in_discovery.sql`
134. `113_dedupe_and_wording.sql`
135. `114_card_confidence_visible.sql`
136. `115_quota_who_says.sql`
137. `116_badges_gate_and_sort.sql`
138. `117_carrier_field.sql`
139. `118_carrier_in_rules.sql`
140. `119_precheck_v5_and_charter.sql`
141. `120_human_text.sql`
142. `121_source_summary.sql`
143. `122_what_can_i_do.sql`
144. `123_overload_cleanup.sql`
145. `124_card_catalog_verified.sql`
146. `125_saw_plaza_partners.sql`
147. `126_partners_visible.sql`
148. `127_ist_tk_from_iga.sql`
149. `128_iga_lounge_and_conflicts.sql`
150. `129_conflict_surfaced.sql`
151. `130_amenities.sql`
152. `131_card_advisor.sql`
153. `132_travel_style.sql`
154. `133_catalog_dedupe.sql`
155. `134_tier_label_everywhere.sql`
156. `135_short_and_honest.sql`
157. `136_otp_honesty.sql`
158. `137_placeholder_vs_data.sql`
159. `138_email_otp.sql`
160. `139_final_polish.sql`
161. `140_rls_and_ratelimit.sql`
162. `141_deletion_flow_check.sql`
163. `142_short_detail_hard.sql`
164. `143_lounge_guide.sql`
165. `144_guide_fixes.sql`
166. `145_null_sort_guard.sql`
167. `146_tk_official_matrix.sql`
168. `147_tier_resolver.sql`
169. `148_rule_matrix_test.sql`
170. `149_multi_entitlement.sql`
171. `150_network_rules_and_guard.sql`
172. `151_deterministic_program_pick.sql`
173. `152_field_reports_loop.sql`
174. `153_host_motivation.sql`
175. `154_membership_tiers.sql`
176. `155_member_cost_visible.sql`
177. `156_official_alignment_and_scope.sql`
178. `157_decision_uses_resolver.sql`
179. `158_device_findings.sql`
180. `159_grants_home_flows_request_gate.sql`
181. `160_catalog_name_dedupe.sql`
182. `161_venue_merge_and_catalog_truth.sql`
183. `162_source_truth_and_founder_badge.sql`
184. `163_unknown_carrier_and_coverage_audit.sql`
185. `164_business_ticket_and_operator_rules.sql`
186. `165_prebeta_security.sql`
187. `166_slot_integrity_and_flow_tests.sql`
188. `167_rule_expectation_matrix.sql`
189. `168_carrier_gap_and_paid_entry.sql`
190. `169_slot_counter_repair.sql`
191. `170_resolution_order_fix.sql`
192. `171_full_matrix_and_report.sql`
193. `172_resolver_full_definition.sql`
194. `173_showcase_data.sql`
195. `174_venue_beats_program_rule.sql`
196. `175_flow_test_cleanup_fix.sql`
197. `176_flow_test_rate_limit.sql`
198. `177_official_table_reconciliation.sql`
199. `178_expectations_single_source.sql`
200. `179_flow_test_skip_semantics.sql`
201. `180_flow_test_future_availability.sql`
202. `181_credit_model_rebalance.sql`
203. `182_discover_carries_decision.sql`
204. `183_lounges_rpc_and_grants.sql`
205. `184_ms_status_language.sql`
206. `185_device_flow_proofs.sql`
207. `186_context_for_cards.sql`
208. `187_kanitlanmis_kusurlar.sql`
209. `188_salon_envanteri.sql`
210. `189_coklu_hak_ve_kaynak_hizalama.sql`
211. `190_salon_tekillestirme_ve_bolum.sql`
212. `191_kaynak_celiskileri_ve_bosluklar.sql`
213. `192_on_kontrol_kapi_hizalama.sql`
214. `193_kart_etiketi_ve_kabin_yazma.sql`
215. `194_bekleme_listesi.sql`
216. `195_ucus_alanlari_ve_kod_paylasimi.sql`
217. `196_plan_ucretleri_ve_celiski_kapanisi.sql`
218. `197_seyahatin_ucus_bilgisi_dolsun.sql`
219. `198_thy_ajet_ms_yeniden_dogrulama.sql`
220. `199_ucus_saati_terminal_ve_katalog.sql`
221. `200_ulke_sozlugu_tekillestirme.sql`
222. `201_banka_karti_tek_cerceve.sql`
223. `202_saat_dilimi_ajet_anahtari_pencere.sql`
224. `203_guvenlik_siniri.sql`
225. `204_blok_eylem_sinirinda.sql`
226. `205_bo_adresi_kendini_kaydeder.sql`
227. `206_host_motoru.sql`
228. `207_kopruler_ve_verilen_sozler.sql`
229. `208_donem_devri_ve_kalibrasyon.sql`
230. `209_saglayici_modulu.sql`
231. `210_abonelik_push_ve_kapsam.sql`
232. `211_kart_aglari_kaynaktan.sql`
233. `212_yonetilen_ayarlar_gercekten_okunuyor.sql`
234. `213_saglayici_kurumsal_katman.sql`
235. `214_misafir_hakki_kaynaktan.sql`
236. `215_saglayici_veri_yollari.sql`
237. `216_hangi_kartimi_kullanayim.sql`
238. `217_misafir_ucreti_geri.sql`
239. `SEED2_KAYNAK_SENARYOLARI.sql`  ← test verisi
240. `SEED_KURAL_SENARYOLARI.sql`  ← test verisi
