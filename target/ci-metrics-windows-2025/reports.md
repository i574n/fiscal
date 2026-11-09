# fiscal CI reports

commit `212e0a8badf15743dea764825065f19ca5bc4d08`, run [42551396881](https://github.com/i574n/fiscal/actions/runs/42551396881), built 2026-11-09 02:39 UTC

## Tests

248 passed, 0 failed, 0 static, 0 skipped, 0 other.

Every test passed.

## Slowest files

| file | seconds | exit |
|---|---|---|
| generator | 1153 | 0 |
| generated_ubl_creditnote_2_1 | 1144.5 | 0 |
| generated_ubl_invoice_2_1 | 981.4 | 0 |
| generated_ubl_despatchadvice_2_1 | 705.4 | 0 |
| generated_nfe_v4 | 688.2 | 0 |
| generated_ubl_receiptadvice_2_1 | 679.2 | 0 |
| generated_ubl_debitnote_2_1 | 532.2 | 0 |
| corpus_checks | 361.7 | 0 |
| generated_ubl_applicationresponse_2_1 | 325.3 | 0 |
| generated_cte_os_v3_00 | 224.3 | 0 |

## Bench (median microseconds)

| unit | parse µs | write µs | runs | bytes | os |
|---|---|---|---|---|---|
| generated_cfdi_pagos_2_0 | 38 | 9 | 31 | 9858 | Microsoft Windows 10.0.26100 |
| generated_cfdi_tfd_1_1 | 17 | 2 | 31 | 6634 | Microsoft Windows 10.0.26100 |
| generated_cfdi_v4_0 | 43 | 10 | 31 | 17391 | Microsoft Windows 10.0.26100 |
| generated_cii_d16b | 87 | 21 | 31 | 10664 | Microsoft Windows 10.0.26100 |
| generated_cl_dte_v10 | 75 | 21 | 31 | 29698 | Microsoft Windows 10.0.26100 |
| generated_cl_envio_dte_v10 | 94 | 25 | 31 | 40734 | Microsoft Windows 10.0.26100 |
| generated_cr_factura_4_4 | 52 | 12 | 31 | 29078 | Microsoft Windows 10.0.26100 |
| generated_cr_factura_compra_4_4 | 75 | 17 | 31 | 42191 | Microsoft Windows 10.0.26100 |
| generated_cr_factura_exportacion_4_4 | 70 | 17 | 31 | 38223 | Microsoft Windows 10.0.26100 |
| generated_cr_mensaje_hacienda_4_4 | 17 | 5 | 31 | 10633 | Microsoft Windows 10.0.26100 |
| generated_cr_mensaje_receptor_4_4 | 27 | 5 | 31 | 11625 | Microsoft Windows 10.0.26100 |
| generated_cr_nota_credito_4_4 | 36 | 8 | 31 | 23281 | Microsoft Windows 10.0.26100 |
| generated_cr_nota_debito_4_4 | 61 | 14 | 31 | 23219 | Microsoft Windows 10.0.26100 |
| generated_cr_recibo_pago_4_4 | 60 | 15 | 31 | 37138 | Microsoft Windows 10.0.26100 |
| generated_cr_tiquete_4_4 | 76 | 17 | 31 | 25761 | Microsoft Windows 10.0.26100 |
| generated_cte_os_v3_00 | 82 | 21 | 31 | 30721 | Microsoft Windows 10.0.26100 |
| generated_cte_os_v4_00 | 135 | 33 | 31 | 31093 | Microsoft Windows 10.0.26100 |
| generated_cte_simp_v4_00 | 130 | 36 | 31 | 47957 | Microsoft Windows 10.0.26100 |
| generated_cte_v2_00 | 112 | 30 | 31 | 38502 | Microsoft Windows 10.0.26100 |
| generated_cte_v3_00 | 112 | 28 | 31 | 39215 | Microsoft Windows 10.0.26100 |
| generated_cte_v4_00 | 114 | 28 | 31 | 39587 | Microsoft Windows 10.0.26100 |
| generated_es_facturae_3_2_2 | 214 | 50 | 31 | 77283 | Microsoft Windows 10.0.26100 |
| generated_es_verifactu | 188 | 28 | 31 | 47678 | Microsoft Windows 10.0.26100 |
| generated_fatturapa_1_2_3 | 77 | 18 | 31 | 46407 | Microsoft Windows 10.0.26100 |
| generated_gr_mydata_2_0_2 | 41 | 9 | 31 | 20398 | Microsoft Windows 10.0.26100 |
| generated_gtve_v3_00 | 180 | 47 | 31 | 42377 | Microsoft Windows 10.0.26100 |
| generated_gtve_v4_00 | 171 | 44 | 31 | 42377 | Microsoft Windows 10.0.26100 |
| generated_hu_nav_3_0 | 97 | 21 | 31 | 41137 | Microsoft Windows 10.0.26100 |
| generated_ksef_fa_3 | 106 | 23 | 31 | 44361 | Microsoft Windows 10.0.26100 |
| generated_mdfe_v1_00 | 71 | 19 | 31 | 28148 | Microsoft Windows 10.0.26100 |
| generated_mdfe_v3_00 | 68 | 18 | 31 | 27993 | Microsoft Windows 10.0.26100 |
| generated_nfe_evento_canc_v1_00 | 71 | 17 | 31 | 22537 | Microsoft Windows 10.0.26100 |
| generated_nfe_evento_cce_v1_00 | 47 | 12 | 31 | 39556 | Microsoft Windows 10.0.26100 |
| generated_nfe_evento_conf_recebto_v1_00 | 64 | 16 | 31 | 21018 | Microsoft Windows 10.0.26100 |
| generated_nfe_v2_00 | 158 | 41 | 31 | 54498 | Microsoft Windows 10.0.26100 |
| generated_nfe_v3_10 | 134 | 34 | 31 | 45260 | Microsoft Windows 10.0.26100 |
| generated_nfe_v4 | 153 | 38 | 31 | 48205 | Microsoft Windows 10.0.26100 |
| generated_pt_saft_1_04_01 | 69 | 14 | 31 | 22165 | Microsoft Windows 10.0.26100 |
| generated_ubl_applicationresponse_2_1 | 17 | 4 | 31 | 4340 | Microsoft Windows 10.0.26100 |
| generated_ubl_creditnote_2_1 | 44 | 12 | 31 | 9517 | Microsoft Windows 10.0.26100 |
| generated_ubl_debitnote_2_1 | 47 | 11 | 31 | 11718 | Microsoft Windows 10.0.26100 |
| generated_ubl_despatchadvice_2_1 | 30 | 6 | 31 | 8959 | Microsoft Windows 10.0.26100 |
| generated_ubl_invoice_2_1 | 56 | 18 | 31 | 11563 | Microsoft Windows 10.0.26100 |
| generated_ubl_receiptadvice_2_1 | 25 | 4 | 31 | 6169 | Microsoft Windows 10.0.26100 |

## Examples

| example | bytes | verdict | first message |
|---|---|---|---|
| generated_nfe_v2_00_example.xml | 1801 | valid |  |
| generated_nfe_v3_10_example.xml | 1503 | valid |  |
| generated_cte_v2_00_example.xml | 1285 | valid |  |
| generated_cte_v3_00_example.xml | 1308 | valid |  |
| generated_cte_v4_00_example.xml | 1320 | valid |  |
| generated_cte_os_v3_00_example.xml | 1034 | valid |  |
| generated_cte_os_v4_00_example.xml | 1046 | valid |  |
| generated_cte_simp_v4_00_example.xml | 1590 | valid |  |
| generated_gtve_v3_00_example.xml | 1410 | valid |  |
| generated_gtve_v4_00_example.xml | 1410 | valid |  |
| generated_mdfe_v1_00_example.xml | 952 | valid |  |
| generated_mdfe_v3_00_example.xml | 947 | valid |  |
| generated_nfe_evento_canc_v1_00_example.xml | 770 | valid |  |
| generated_nfe_evento_cce_v1_00_example.xml | 1319 | valid |  |
| generated_nfe_evento_conf_recebto_v1_00_example.xml | 721 | valid |  |
| generated_ubl_debitnote_2_1_example.xml | 694 | valid |  |
| generated_ubl_applicationresponse_2_1_example.xml | 466 | valid |  |
| generated_ubl_despatchadvice_2_1_example.xml | 610 | valid |  |
| generated_ubl_receiptadvice_2_1_example.xml | 519 | valid |  |
| generated_cr_factura_compra_4_4_example.xml | 1454 | valid |  |
| generated_cr_factura_exportacion_4_4_example.xml | 1331 | valid |  |
| generated_cr_nota_credito_4_4_example.xml | 842 | valid |  |
| generated_cr_nota_debito_4_4_example.xml | 839 | valid |  |
| generated_cr_tiquete_4_4_example.xml | 918 | valid |  |
| generated_cr_recibo_pago_4_4_example.xml | 1288 | valid |  |
| generated_cr_mensaje_receptor_4_4_example.xml | 459 | valid |  |
| generated_cr_mensaje_hacienda_4_4_example.xml | 427 | valid |  |
| generated_nfe_v4_example.xml | 1598 | valid |  |
| generated_cfdi_v4_0_example.xml | 597 | valid |  |
| generated_cfdi_tfd_1_1_example.xml | 264 | valid |  |
| generated_cfdi_pagos_2_0_example.xml | 356 | valid |  |
| generated_cl_dte_v10_example.xml | 991 | valid |  |
| generated_cl_envio_dte_v10_example.xml | 1387 | valid |  |
| generated_cr_factura_4_4_example.xml | 1025 | valid |  |
| generated_ubl_invoice_2_1_example.xml | 687 | valid |  |
| generated_ubl_creditnote_2_1_example.xml | 624 | valid |  |
| generated_fatturapa_1_2_3_example.xml | 1573 | valid |  |
| generated_ksef_fa_3_example.xml | 1480 | valid |  |
| generated_es_facturae_3_2_2_example.xml | 2571 | valid |  |
| generated_es_verifactu_example.xml | 1810 | valid |  |
| generated_gr_mydata_2_0_2_example.xml | 705 | valid |  |
| generated_in_gst_inv01_1_1_example.json | 459 | valid |  |

## Canon census (the 24 required EN 16931 terms)

| family | bound | implied | derived | national code | not carried |
|---|---|---|---|---|---|
| NF-e 4.00 | 11 | 2 | 4 | 4 | 3 |
| CFDI 4.0 | 11 | 1 | 5 | 3 | 4 |

## Modeling ceiling (typed / schema-expressible, per family)

| family | typed | expressible | ceiling % | untyped kinds |
|---|---|---|---|---|
| nfe_v2_00 | 515 | 516 | 99 |  |
| nfe_v3_10 | 622 | 623 | 99 |  |
| cte_v2_00 | 429 | 438 | 97 |  |
| cte_v3_00 | 722 | 734 | 98 |  |
| cte_v4_00 | 970 | 982 | 98 | bounds-facet |
| cte_os_v3_00 | 722 | 734 | 98 |  |
| cte_os_v4_00 | 970 | 982 | 98 | bounds-facet |
| cte_simp_v4_00 | 970 | 982 | 98 | bounds-facet |
| gtve_v3_00 | 722 | 734 | 98 |  |
| gtve_v4_00 | 970 | 982 | 98 | bounds-facet |
| mdfe_v1_00 | 234 | 239 | 97 |  |
| mdfe_v3_00 | 345 | 349 | 98 |  |
| nfe_evento_canc_v1_00 | 101 | 108 | 93 |  |
| nfe_evento_cce_v1_00 | 104 | 111 | 93 |  |
| nfe_evento_conf_recebto_v1_00 | 103 | 111 | 92 |  |
| ubl_debitnote_2_1 | 2387 | 3301 | 72 |  |
| ubl_applicationresponse_2_1 | 2356 | 3270 | 72 |  |
| ubl_despatchadvice_2_1 | 2363 | 3277 | 72 |  |
| ubl_receiptadvice_2_1 | 2363 | 3277 | 72 |  |
| cr_factura_compra_4_4 | 190 | 215 | 88 | digits-facet, bounds-facet |
| cr_factura_exportacion_4_4 | 198 | 227 | 87 | digits-facet, bounds-facet |
| cr_nota_credito_4_4 | 233 | 278 | 83 | digits-facet, bounds-facet |
| cr_nota_debito_4_4 | 233 | 278 | 83 | digits-facet, bounds-facet |
| cr_tiquete_4_4 | 221 | 266 | 83 | digits-facet, bounds-facet |
| cr_recibo_pago_4_4 | 95 | 104 | 91 | digits-facet, bounds-facet |
| cr_mensaje_receptor_4_4 | 58 | 62 | 93 | digits-facet, bounds-facet |
| cr_mensaje_hacienda_4_4 | 54 | 56 | 96 | digits-facet |
| nfe_v4 | 951 | 953 | 99 | bounds-facet |
| cfdi_v4_0 | 123 | 158 | 77 | digits-facet, bounds-facet |
| cfdi_tfd_1_1 | 29 | 36 | 80 | digits-facet, bounds-facet, record |
| cfdi_pagos_2_0 | 84 | 109 | 77 | digits-facet, bounds-facet |
| cl_dte_v10 | 674 | 795 | 84 | digits-facet, bounds-facet |
| cl_envio_dte_v10 | 678 | 801 | 84 | digits-facet, bounds-facet |
| cr_factura_4_4 | 224 | 269 | 83 | digits-facet, bounds-facet |
| ubl_invoice_2_1 | 2392 | 3306 | 72 |  |
| ubl_creditnote_2_1 | 2389 | 3303 | 72 |  |
| fatturapa_1_2_3 | 265 | 285 | 92 | bounds-facet |
| ksef_fa_3 | 423 | 452 | 93 | digits-facet, bounds-facet |
| es_facturae_3_2_2 | 301 | 301 | 100 |  |
| es_verifactu | 213 | 213 | 100 |  |
| pt_saft_1_04_01 | 524 | 552 | 94 | bounds-facet |
| cii_d16b | 1022 | 1086 | 94 |  |
| gr_mydata_2_0_2 | 194 | 231 | 83 | digits-facet, bounds-facet |
| hu_nav_3_0 | 282 | 302 | 93 | digits-facet, bounds-facet |
| in_gst_inv01_1_1 | 296 | 351 | 84 | bounds-facet |
