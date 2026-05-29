-- 申请备注微信昵称/号，便于主理人对账
ALTER TABLE post_applications
    ADD COLUMN IF NOT EXISTS wechat_contact VARCHAR(128) NOT NULL DEFAULT '';
