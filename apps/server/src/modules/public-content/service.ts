import { sql } from 'drizzle-orm';
import type { z } from 'zod';
import type { Db } from '../../core/database.js';
import { requireValue } from '../../core/errors.js';
import { audit } from '../../core/transactions.js';
import { organization } from '../organizations/service.js';
import type { Actor } from '../../../../../packages/shared/src/schemas.js';
import { contentSchema } from '../../../../../packages/shared/src/schemas.js';
export async function saveContent(tx:Db,a:Actor,d:z.infer<typeof contentSchema>){
 const before=await organization(tx,a.org_id);
 const [v]=await tx.all(sql`UPDATE organizations SET village_title=${d.village_title},village_body=${d.village_body},village_image_id=${d.village_image_id},publication=${d.publication} WHERE id=${a.org_id} RETURNING *`);
 await audit(tx,a,'PUBLIC_CONTENT_UPDATED','ORGANIZATION',a.org_id,{village_title:before.village_title,village_body:before.village_body,village_image_id:before.village_image_id,publication:before.publication},d);return v;
}
const imageUrl=(slug:string,id:string|null)=>id?`/api/v1/public/${encodeURIComponent(slug)}/files/${id}`:null;
export async function publicData(db:Db,slug:string){
 const org=requireValue((await db.all(sql`SELECT id,name,slug,village_title,village_body,village_image_id,publication FROM organizations WHERE slug=${slug}`))[0],'Organisasi belum tersedia.');
 const products=await db.all(sql`SELECT p.id,p.name,p.description,p.image_id,p.shopee_url,p.tokopedia_url,p.whatsapp_url,v.price_rp FROM products p JOIN LATERAL (SELECT price_rp FROM product_versions WHERE org_id=p.org_id AND product_id=p.id ORDER BY version DESC LIMIT 1) v ON true WHERE p.org_id=${org.id} AND p.publication='PUBLISHED' AND NOT p.archived ORDER BY p.name,p.id`);
 const farmers=await db.all(sql`SELECT id,name,bio,image_id FROM farmers WHERE org_id=${org.id} AND publication='PUBLISHED' AND NOT archived ORDER BY name,id`);
 return {organization:{name:org.name,slug:org.slug},village:org.publication==='PUBLISHED'?{title:org.village_title,body:org.village_body,imageUrl:imageUrl(slug,org.village_image_id)}:null,products:products.map(p=>({id:p.id,name:p.name,description:p.description,imageUrl:imageUrl(slug,p.image_id),sellingPrice:String(p.price_rp),shopeeUrl:p.shopee_url,tokopediaUrl:p.tokopedia_url,whatsappUrl:p.whatsapp_url})),farmers:farmers.map(f=>({id:f.id,name:f.name,bio:f.bio,imageUrl:imageUrl(slug,f.image_id)}))};
}
