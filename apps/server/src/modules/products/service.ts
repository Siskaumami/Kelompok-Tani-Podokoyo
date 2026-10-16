import { sql } from 'drizzle-orm';
import type { z } from 'zod';
import type { Db } from '../../core/database.js';
import { assert, checked, requireValue } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import type { Actor } from '../../../../../packages/shared/src/schemas.js';
import { createProductSchema, productSchema, economicsSchema } from '../../../../../packages/shared/src/schemas.js';
export async function product(db:Db,org:string,id:string){return requireValue((await db.all(sql`SELECT * FROM products WHERE org_id=${org} AND id=${id}`))[0]);}
export async function economics(db:Db,org:string,id:string){return requireValue((await db.all(sql`SELECT * FROM product_versions WHERE org_id=${org} AND product_id=${id} ORDER BY version DESC LIMIT 1`))[0]);}
export async function productList(db:Db,org:string){return db.all(sql`SELECT p.*,v.id AS version_id,v.version,v.material_g,v.material_rp,v.packaging_rp,v.production_rp,v.other_rp,v.hpp_rp,v.price_rp,i.id AS item_id,i.balance FROM products p JOIN LATERAL (SELECT * FROM product_versions WHERE org_id=p.org_id AND product_id=p.id ORDER BY version DESC LIMIT 1) v ON true JOIN inventory_items i ON i.org_id=p.org_id AND i.product_id=p.id WHERE p.org_id=${org} ORDER BY p.created_at DESC,p.id`);}
export async function appendEconomics(tx:Db,a:Actor,id:string,data:z.infer<typeof economicsSchema>){
 const p=await product(tx,a.org_id,id);assert(!p.archived,'Produk sudah diarsipkan.');
 checked(BigInt(data.material_rp)+BigInt(data.packaging_rp)+BigInt(data.production_rp)+BigInt(data.other_rp));
 const before=(await tx.all(sql`SELECT * FROM product_versions WHERE org_id=${a.org_id} AND product_id=${id} ORDER BY version DESC LIMIT 1`))[0]??null;
 const [v]=await tx.all(sql`INSERT INTO product_versions(org_id,product_id,version,material_g,material_rp,packaging_rp,production_rp,other_rp,price_rp,changed_by,reason) VALUES(${a.org_id},${id},${before?before.version+1:1},${data.material_g},${data.material_rp},${data.packaging_rp},${data.production_rp},${data.other_rp},${data.price_rp},${a.id},${data.reason}) RETURNING *`);
 await audit(tx,a,'PRODUCT_ECONOMICS_CHANGED','PRODUCT',id,before,v,data.reason);return v;
}
export async function createProduct(tx:Db,a:Actor,data:z.infer<typeof createProductSchema>){
 const [p]=await tx.all(sql`INSERT INTO products(org_id,name,sku,description,image_id,publication,shopee_url,tokopedia_url,whatsapp_url) VALUES(${a.org_id},${data.name},${data.sku},${data.description},${data.image_id},${data.publication},${data.shopee_url},${data.tokopedia_url},${data.whatsapp_url}) RETURNING *`);
 await appendEconomics(tx,a,p.id,data.economics);
 await tx.all(sql`INSERT INTO inventory_items(org_id,product_id,kind) VALUES(${a.org_id},${p.id},'FINISHED')`);
 await audit(tx,a,'PRODUCT_CREATED','PRODUCT',p.id,null,p);return p;
}
export async function updateProduct(tx:Db,a:Actor,id:string,data:z.infer<typeof productSchema>){
 const before=await product(tx,a.org_id,id);
 const [p]=await tx.all(sql`UPDATE products SET name=${data.name},sku=${data.sku},description=${data.description},image_id=${data.image_id},publication=${data.publication},shopee_url=${data.shopee_url},tokopedia_url=${data.tokopedia_url},whatsapp_url=${data.whatsapp_url} WHERE org_id=${a.org_id} AND id=${id} RETURNING *`);
 await audit(tx,a,'PRODUCT_UPDATED','PRODUCT',id,before,p);return p;
}
export async function archiveProduct(tx:Db,a:Actor,id:string){
 const before=await product(tx,a.org_id,id);
 const [p]=await tx.all(sql`UPDATE products SET archived=true,publication='DRAFT' WHERE org_id=${a.org_id} AND id=${id} RETURNING *`);
 await tx.all(sql`UPDATE production_plans SET status='CANCELLED' WHERE org_id=${a.org_id} AND product_id=${id} AND status IN ('OPEN','NEEDS_REVIEW')`);
 await audit(tx,a,'PRODUCT_ARCHIVED','PRODUCT',id,before,p);return p;
}
