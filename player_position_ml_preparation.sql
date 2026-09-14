--Hipotez: Oyuncunun Teknik Özelliklerine Göre Mevkisinin (Orta Saha/ Forvet/Kaleci/Defans) Tahmin Edilmesi bizim oyuncu mevkilerini belirlememiz için gereken bilgiler nedir? 
--A) (Tahmin): "Oyuncunun teknik özelliklerine bakarak, hangi mevkide oynadığını/oynayacağını tahmin etmek." (YAPILMADI)
--B) (Öneri/Optimizasyon): "Oyuncuyu teknik özelliklerine göre hangi mevkide oynatırsak daha başarılı olur."
--Bu da bir sınıflandırma veya skorlama problemi olabilir ama "başarı" tanımı gerekiyor (örn. overall_rating).
--Girdi: teknik özellikler. Çıktı: en yüksek overall_rating'i verecek mevki tahmini.


-- =====================================================================
-- ADIM 1: PLAYER_ATTRIBUTES TABLOSUNA İLK BAKIŞ
-- Amaç: Hiçbir değişiklik yapmadan, tabloda kaç satır olduğunu ve
-- verinin nasıl göründüğünü görmek.
 
SELECT *
FROM `fatihdata.european_hipotez.Player_Attributes`
LIMIT 10;

-- =====================================================================
-- ADIM 2: PLAYER_ATTRIBUTES - NULL (BOŞ) DEĞER KONTROLÜ
-- Amaç: Önemli sütunlarda kaç adet boş değer olduğunu görmek.
-- Bu sayılar yüksekse, o sütunları kullanmadan önce karar vermemiz
-- gerekecek (satırı silmek mi, doldurmak mı).
-- =====================================================================
 
SELECT
  COUNT(*) AS toplam_satir,
  COUNTIF(overall_rating IS NULL) AS bos_overall_rating,
  COUNTIF(crossing IS NULL) AS bos_crossing,
  COUNTIF(finishing IS NULL) AS bos_finishing,
  COUNTIF(marking IS NULL) AS bos_marking,
  COUNTIF(standing_tackle IS NULL) AS bos_standing_tackle,
  COUNTIF(gk_reflexes IS NULL) AS bos_gk_reflexes,
  COUNTIF(player_api_id IS NULL) AS bos_player_api_id,
  COUNTIF(date IS NULL) AS bos_date
FROM `fatihdata.european_hipotez.Player_Attributes`;

-- =====================================================================
-- ADIM 3: PLAYER_ATTRIBUTES - VERİ TİPİ KONTROLÜ
-- Amaç: Önemli sütunların hangi veri tipinde (INTEGER, FLOAT, STRING,
--       DATE vb.) kayıtlı olduğunu görmek.
-- =====================================================================

SELECT column_name, data_type
FROM `fatihdata.european_hipotez.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'Player_Attributes'
ORDER BY ordinal_position;

-- =====================================================================
-- ADIM 4: TEKİLLEŞTİRME ÖNCESİ TEST
-- Amaç: Tek bir oyuncuyu (örnek) seçip, gerçekten birden fazla tarihte
--       kaydı olup olmadığını gözle görmek.
-- =====================================================================

SELECT
  player_api_id,
  date,
  overall_rating,
  crossing,
  finishing,
  marking
FROM `fatihdata.european_hipotez.Player_Attributes`
WHERE player_api_id = (
  SELECT player_api_id
  FROM `fatihdata.european_hipotez.Player_Attributes`
  LIMIT 1
)
ORDER BY date DESC;

-- =====================================================================
-- ADIM 4a: TEKİLLEŞTİRME - HER OYUNCU İÇİN EN GÜNCEL SATIRI SEÇME
-- Amaç: Player_Attributes tablosunda her oyuncunun birden fazla
--       tarihli kaydı var. Her oyuncu için SADECE en güncel tarihli
--       satırı seçip, "oyuncu başına 1 satır" olan yeni bir tablo
--       oluşturmak.
-- =====================================================================

CREATE OR REPLACE TABLE `fatihdata.european_hipotez.player_attributes_latest` AS

SELECT
  player_api_id,
  date,
  overall_rating,
  crossing,
  finishing,
  heading_accuracy,
  short_passing,
  volleys,
  dribbling,
  curve,
  free_kick_accuracy,
  long_passing,
  ball_control,
  acceleration,
  sprint_speed,
  agility,
  reactions,
  balance,
  shot_power,
  jumping,
  stamina,
  strength,
  long_shots,
  aggression,
  interceptions,
  positioning,
  vision,
  penalties,
  marking,
  standing_tackle,
  sliding_tackle,
  gk_diving,
  gk_handling,
  gk_kicking,
  gk_positioning,
  gk_reflexes
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY player_api_id ORDER BY date DESC) AS rn
  FROM `fatihdata.european_hipotez.Player_Attributes`
  WHERE overall_rating IS NOT NULL  -- Adım 2'de bulduğumuz 836 boş satırı eliyoruz
)
WHERE rn = 1;

-- =====================================================================
-- ADIM 5: YENİ TABLONUN DOĞRULAMASI
-- Amaç: player_attributes_latest tablosunda kaç satır olduğunu görmek
--       ve her oyuncunun gerçekten TEK satırı olduğunu (tekrar yok)
--       doğrulamak.
-- =====================================================================

SELECT
  COUNT(*) AS toplam_satir,
  COUNT(DISTINCT player_api_id) AS tekil_oyuncu_sayisi
FROM `fatihdata.european_hipotez.player_attributes_latest`;

-- =====================================================================
-- ADIM 6: MATCH TABLOSUNA İLK BAKIŞ
-- Amaç: Hiçbir değişiklik yapmadan, bizim için önemli sütunların
--       (match_api_id, oyuncu kimlikleri, Y koordinatları) nasıl
--       göründüğünü görmek.
-- =====================================================================

SELECT
  match_api_id,
  home_player_1,
  home_player_Y1,
  home_player_2,
  home_player_Y2,
  away_player_1,
  away_player_Y1
FROM `fatihdata.european_hipotez.Match`
LIMIT 10;

-- =====================================================================
-- ADIM 6a: KADRO BİLGİSİ DOLU/BOŞ MAÇ SAYISI
-- Amaç: Toplam kaç maç var, bunlardan kaçında home_player_1 (kadro
--       bilgisi) dolu, kaçında boş olduğunu görmek.
-- =====================================================================

SELECT
  COUNT(*) AS toplam_mac,
  COUNTIF(home_player_1 IS NOT NULL) AS kadro_dolu_mac,
  COUNTIF(home_player_1 IS NULL) AS kadro_bos_mac
FROM `fatihdata.european_hipotez.Match`;

-- =====================================================================
-- ADIM 7: KADROSU DOLU ÖRNEK BİR MAÇ
-- Amaç: home_player_1 boş OLMAYAN satırları filtreleyip, gerçekten
--       dolu veriye sahip bir maçın nasıl göründüğünü görmek.
-- =====================================================================

SELECT
  match_api_id,
  home_player_1,
  home_player_Y1,
  home_player_2,
  home_player_Y2,
  away_player_1,
  away_player_Y1
FROM `fatihdata.european_hipotez.Match`
WHERE home_player_1 IS NOT NULL
LIMIT 10;

-- =====================================================================
-- ADIM 8: OYUNCU KİMLİĞİ DOLU AMA Y KOORDİNATI BOŞ OLAN SATIRLAR
-- Amaç: home_player_1 dolu olduğu halde home_player_Y1'in boş olduğu
--       kaç satır olduğunu görmek. Bu durum varsa, sadece
--       "home_player_1 IS NOT NULL" filtresi yeterli değil demektir.
-- =====================================================================

SELECT
  COUNT(*) AS toplam_mac,
  COUNTIF(home_player_1 IS NOT NULL AND home_player_Y1 IS NOT NULL) AS hem_id_hem_y_dolu,
  COUNTIF(home_player_1 IS NOT NULL AND home_player_Y1 IS NULL) AS id_dolu_y_bos
FROM `fatihdata.european_hipotez.Match`;

-- =====================================================================
-- ADIM 9: TEK BİR OYUNCU SLOTUNU DOĞRU FİLTREYLE TEST ETME
-- Amaç: home_player_1 ve home_player_Y1'i, ikisi de dolu olacak
--       şekilde filtreleyip çekmek. Bu, unpivot işleminin küçük
--       ölçekli bir denemesi.
-- =====================================================================

SELECT
  match_api_id,
  home_player_1 AS player_api_id,
  home_player_Y1 AS y_value
FROM `fatihdata.european_hipotez.Match`
WHERE home_player_1 IS NOT NULL
  AND home_player_Y1 IS NOT NULL
LIMIT 10;

-- =====================================================================
-- ADIM 10: TÜM 22 OYUNCU SLOTUNU BİRLEŞTİRME (UNPIVOT)
-- Amaç: Match tablosundaki 22 oyuncu sütununu (11 ev sahibi +
--       11 deplasman) alt alta dizip, "1 satır = 1 oyuncu-maç"
--       formatına çevirmek. Sadece hem oyuncu kimliği hem Y
--       koordinatı dolu olan satırlar alınıyor (Adım 8'de
--       belirlediğimiz filtre).
-- =====================================================================

CREATE OR REPLACE TABLE `fatihdata.european_hipotez.match_player_y_unpivoted` AS

SELECT match_api_id, home_player_1 AS player_api_id, home_player_Y1 AS y_value FROM `fatihdata.european_hipotez.Match` WHERE home_player_1 IS NOT NULL AND home_player_Y1 IS NOT NULL
UNION ALL SELECT match_api_id, home_player_2, home_player_Y2 FROM `fatihdata.european_hipotez.Match` WHERE home_player_2 IS NOT NULL AND home_player_Y2 IS NOT NULL
UNION ALL SELECT match_api_id, home_player_3, home_player_Y3 FROM `fatihdata.european_hipotez.Match` WHERE home_player_3 IS NOT NULL AND home_player_Y3 IS NOT NULL
UNION ALL SELECT match_api_id, home_player_4, home_player_Y4 FROM `fatihdata.european_hipotez.Match` WHERE home_player_4 IS NOT NULL AND home_player_Y4 IS NOT NULL
UNION ALL SELECT match_api_id, home_player_5, home_player_Y5 FROM `fatihdata.european_hipotez.Match` WHERE home_player_5 IS NOT NULL AND home_player_Y5 IS NOT NULL
UNION ALL SELECT match_api_id, home_player_6, home_player_Y6 FROM `fatihdata.european_hipotez.Match` WHERE home_player_6 IS NOT NULL AND home_player_Y6 IS NOT NULL
UNION ALL SELECT match_api_id, home_player_7, home_player_Y7 FROM `fatihdata.european_hipotez.Match` WHERE home_player_7 IS NOT NULL AND home_player_Y7 IS NOT NULL
UNION ALL SELECT match_api_id, home_player_8, home_player_Y8 FROM `fatihdata.european_hipotez.Match` WHERE home_player_8 IS NOT NULL AND home_player_Y8 IS NOT NULL
UNION ALL SELECT match_api_id, home_player_9, home_player_Y9 FROM `fatihdata.european_hipotez.Match` WHERE home_player_9 IS NOT NULL AND home_player_Y9 IS NOT NULL
UNION ALL SELECT match_api_id, home_player_10, home_player_Y10 FROM `fatihdata.european_hipotez.Match` WHERE home_player_10 IS NOT NULL AND home_player_Y10 IS NOT NULL
UNION ALL SELECT match_api_id, home_player_11, home_player_Y11 FROM `fatihdata.european_hipotez.Match` WHERE home_player_11 IS NOT NULL AND home_player_Y11 IS NOT NULL
UNION ALL SELECT match_api_id, away_player_1, away_player_Y1 FROM `fatihdata.european_hipotez.Match` WHERE away_player_1 IS NOT NULL AND away_player_Y1 IS NOT NULL
UNION ALL SELECT match_api_id, away_player_2, away_player_Y2 FROM `fatihdata.european_hipotez.Match` WHERE away_player_2 IS NOT NULL AND away_player_Y2 IS NOT NULL
UNION ALL SELECT match_api_id, away_player_3, away_player_Y3 FROM `fatihdata.european_hipotez.Match` WHERE away_player_3 IS NOT NULL AND away_player_Y3 IS NOT NULL
UNION ALL SELECT match_api_id, away_player_4, away_player_Y4 FROM `fatihdata.european_hipotez.Match` WHERE away_player_4 IS NOT NULL AND away_player_Y4 IS NOT NULL
UNION ALL SELECT match_api_id, away_player_5, away_player_Y5 FROM `fatihdata.european_hipotez.Match` WHERE away_player_5 IS NOT NULL AND away_player_Y5 IS NOT NULL
UNION ALL SELECT match_api_id, away_player_6, away_player_Y6 FROM `fatihdata.european_hipotez.Match` WHERE away_player_6 IS NOT NULL AND away_player_Y6 IS NOT NULL
UNION ALL SELECT match_api_id, away_player_7, away_player_Y7 FROM `fatihdata.european_hipotez.Match` WHERE away_player_7 IS NOT NULL AND away_player_Y7 IS NOT NULL
UNION ALL SELECT match_api_id, away_player_8, away_player_Y8 FROM `fatihdata.european_hipotez.Match` WHERE away_player_8 IS NOT NULL AND away_player_Y8 IS NOT NULL
UNION ALL SELECT match_api_id, away_player_9, away_player_Y9 FROM `fatihdata.european_hipotez.Match` WHERE away_player_9 IS NOT NULL AND away_player_Y9 IS NOT NULL
UNION ALL SELECT match_api_id, away_player_10, away_player_Y10 FROM `fatihdata.european_hipotez.Match` WHERE away_player_10 IS NOT NULL AND away_player_Y10 IS NOT NULL
UNION ALL SELECT match_api_id, away_player_11, away_player_Y11 FROM `fatihdata.european_hipotez.Match` WHERE away_player_11 IS NOT NULL AND away_player_Y11 IS NOT NULL;

-- =====================================================================
-- ADIM 11: UNPIVOT TABLOSUNUN DOĞRULAMASI
-- Amaç: match_player_y_unpivoted tablosunda kaç satır olduğunu
--       görmek. Beklenen değer kabaca 500.000 civarı (24.032 maç
--       x ortalama ~22 oyuncu).
-- =====================================================================

SELECT
  COUNT(*) AS toplam_satir,
  COUNT(DISTINCT player_api_id) AS tekil_oyuncu_sayisi,
  COUNT(DISTINCT match_api_id) AS tekil_mac_sayisi
FROM `fatihdata.european_hipotez.match_player_y_unpivoted`;

-- =====================================================================
-- ADIM 12: Y DEĞERİNE GÖRE MEVKİ BANDI ETİKETLEME
-- Amaç: match_player_y_unpivoted tablosundaki her satıra, y_value
--       değerine göre mevki etiketi eklemek.
--
-- Daha önce gerçek veri dağılımına göre belirlediğimiz kurallar:
--   y_value = 0, 1        -> Kaleci
--   y_value = 3           -> Defans
--   y_value = 5, 6, 7      -> Orta Saha
--   y_value = 8, 9, 10, 11  -> Forvet
-- =====================================================================

CREATE OR REPLACE TABLE `fatihdata.european_hipotez.match_player_position_banded` AS

SELECT
  match_api_id,
  player_api_id,
  y_value,
  CASE
    WHEN y_value IN (0, 1)         THEN 'Kaleci'
    WHEN y_value = 3               THEN 'Defans'
    WHEN y_value IN (5, 6, 7)      THEN 'Orta Saha'
    WHEN y_value IN (8, 9, 10, 11) THEN 'Forvet'
    ELSE NULL
  END AS position_band
FROM `fatihdata.european_hipotez.match_player_y_unpivoted`;

-- =====================================================================
-- ADIM 13: MEVKİ BANDI DAĞILIMI DOĞRULAMASI
-- Amaç: Kaleci / Defans / Orta Saha / Forvet etiketlerinden kaçar
--       adet oyuncu-maç kaydı olduğunu görmek. Bu, az önce Y
--       dağılımında gördüğümüz frekanslarla uyumlu olmalı.
-- =====================================================================

SELECT
  position_band,
  COUNT(*) AS kayit_sayisi
FROM `fatihdata.european_hipotez.match_player_position_banded`
GROUP BY position_band
ORDER BY kayit_sayisi DESC;


-- =====================================================================
-- ADIM 14: HER OYUNCU İÇİN HER MEVKİDE KAÇ KEZ OYNADIĞINI SAYMA
-- Amaç: Her oyuncu - mevki bandı kombinasyonu için kaç maç
--       oynandığını saymak. Bu, bir sonraki adımda "en sık oynanan
--       mevkiyi" bulmamız için gerekli ara tablo.
-- =====================================================================

CREATE OR REPLACE TABLE `fatihdata.european_hipotez.player_position_counts` AS

SELECT
  player_api_id,
  position_band,
  COUNT(*) AS band_sayisi
FROM `fatihdata.european_hipotez.match_player_position_banded`
WHERE position_band IS NOT NULL
GROUP BY player_api_id, position_band;

-- =====================================================================
-- ADIM 14a: ÖRNEK BİR OYUNCUNUN MEVKİ SAYILARINI GÖRME
-- Amaç: player_position_counts tablosundan, birden fazla mevkide
--       görünen bir oyuncuyu örnek olarak seçip, sayıların mantıklı
--       göründüğünü gözle teyit etmek.
-- =====================================================================

SELECT
  player_api_id,
  position_band,
  band_sayisi
FROM `fatihdata.european_hipotez.player_position_counts`
WHERE player_api_id IN (
  -- En çok kayda sahip (en çok maç oynamış) ilk 1 oyuncuyu bul
  SELECT player_api_id
  FROM `fatihdata.european_hipotez.player_position_counts`
  GROUP BY player_api_id
  HAVING COUNT(*) > 1   -- birden fazla bantta oynamış olanları seç
  LIMIT 1
)
ORDER BY band_sayisi DESC;

-- =====================================================================
-- ADIM 15: HER OYUNCU İÇİN EN SIK OYNADIĞI MEVKİYİ SEÇME
-- Amaç: player_position_counts tablosundan, her oyuncu için
--       en yüksek band_sayisi'na sahip olan satırı seçmek.
--       Bu, oyuncunun nihai (final) mevki etiketi olacak.
-- =====================================================================

CREATE OR REPLACE TABLE `fatihdata.european_hipotez.player_position_labels` AS

WITH siralanmis AS (
  SELECT
    player_api_id,
    position_band,
    band_sayisi,
    ROW_NUMBER() OVER (PARTITION BY player_api_id ORDER BY band_sayisi DESC) AS sira,
    SUM(band_sayisi) OVER (PARTITION BY player_api_id) AS toplam_mac
  FROM `fatihdata.european_hipotez.player_position_counts`
)

SELECT
  player_api_id,
  position_band AS position_label,
  band_sayisi AS mevkide_oynadigi_mac_sayisi,
  toplam_mac,
  ROUND(band_sayisi / toplam_mac, 3) AS tutarlilik_orani
FROM siralanmis
WHERE sira = 1;

-- =====================================================================
-- ADIM 16: MEVKİ ETİKETİ TABLOSUNUN DOĞRULAMASI
-- Amaç: player_position_labels tablosunda toplam kaç oyuncu olduğunu
--       ve her mevki etiketinden (Kaleci/Defans/Orta Saha/Forvet)
--       kaçar oyuncu olduğunu görmek.
-- =====================================================================

SELECT
  position_label,
  COUNT(*) AS oyuncu_sayisi
FROM `fatihdata.european_hipotez.player_position_labels`
GROUP BY position_label
ORDER BY oyuncu_sayisi DESC;

-- =====================================================================
-- ADIM 17: İKİ TABLOYU JOIN ETME (FİNAL ML TABLOSU)
-- Amaç: player_attributes_latest (teknik özellikler) ile
--       player_position_labels (mevki etiketi) tablolarını
--       player_api_id üzerinden birleştirip, Python'a aktaracağımız
--       final tabloyu oluşturmak.
--
-- INNER JOIN kullanıyoruz çünkü bize hem teknik özelliği hem mevki
-- etiketi olan oyuncular gerekli; sadece birinde olan oyuncu işimize
-- yaramaz.
-- =====================================================================

CREATE OR REPLACE TABLE `fatihdata.european_hipotez.ml_hipotez17b_final` AS

SELECT
  pa.player_api_id,
  pa.overall_rating,
  pa.crossing,
  pa.finishing,
  pa.heading_accuracy,
  pa.short_passing,
  pa.volleys,
  pa.dribbling,
  pa.curve,
  pa.free_kick_accuracy,
  pa.long_passing,
  pa.ball_control,
  pa.acceleration,
  pa.sprint_speed,
  pa.agility,
  pa.reactions,
  pa.balance,
  pa.shot_power,
  pa.jumping,
  pa.stamina,
  pa.strength,
  pa.long_shots,
  pa.aggression,
  pa.interceptions,
  pa.positioning,
  pa.vision,
  pa.penalties,
  pa.marking,
  pa.standing_tackle,
  pa.sliding_tackle,
  pa.gk_diving,
  pa.gk_handling,
  pa.gk_kicking,
  pa.gk_positioning,
  pa.gk_reflexes,
  pl.position_label,
  pl.tutarlilik_orani
FROM `fatihdata.european_hipotez.player_attributes_latest` AS pa
INNER JOIN `fatihdata.european_hipotez.player_position_labels` AS pl
  ON pa.player_api_id = pl.player_api_id;

  -- =====================================================================
-- ADIM 18: FİNAL TABLONUN DOĞRULAMASI
-- Amaç: ml_hipotez17b_final tablosunda toplam kaç oyuncu olduğunu
--       ve mevki etiketine göre dağılımı görmek.
-- =====================================================================

SELECT
  position_label,
  COUNT(*) AS oyuncu_sayisi
FROM `fatihdata.european_hipotez.ml_hipotez17b_final`
GROUP BY position_label
ORDER BY oyuncu_sayisi DESC;






