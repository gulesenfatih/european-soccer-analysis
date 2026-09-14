CREATE OR REPLACE VIEW `fatihdata.european_soccer_analysis.stg_oyuncu_nitelikleri` AS
WITH ranked_attributes AS (
    SELECT
        player_api_id,
        date AS rating_date,
        overall_rating,
        potential,
        preferred_foot,
        crossing,
        finishing,
        short_passing,
        stamina,
        strength,
        ROW_NUMBER() OVER(PARTITION BY player_api_id, date ORDER BY id DESC) as group_rn
    FROM `fatihdata.european_soccer_analysis.Player_Attributes`
)
SELECT
    player_api_id,
    rating_date,
    overall_rating,
    potential,
    preferred_foot,
    crossing,
    finishing,
    short_passing,
    stamina,
    strength
FROM ranked_attributes
WHERE group_rn = 1;