import type { ReactNode, ChangeEvent } from 'react';
import { ArrowLeft, Camera, MessageCircle, Package, Settings, Share2, ShieldCheck, Store } from 'lucide-react';

type Seller={user_id:string;store_name:string;description:string;cover_path?:string|null};
type Profile={id:string;display_name:string;username:string;photo_path?:string|null}|null;
type Props={
 seller:Seller;profile:Profile;isOwner:boolean;coverUrl:string;photoUrl:string;children:ReactNode;
 onBack:()=>void;onEdit:()=>void;onShare:()=>void;onWhatsApp:()=>void;
 onProfilePhoto:(event:ChangeEvent<HTMLInputElement>)=>void;
 onCoverPhoto:(event:ChangeEvent<HTMLInputElement>)=>void;
 profilePhotoBusy:boolean;coverPhotoBusy:boolean;
};
export default function SellerProfilePage(props:Props){
 const {seller,profile,isOwner,coverUrl,photoUrl,children,onBack,onEdit,onShare,onWhatsApp,onProfilePhoto,onCoverPhoto,profilePhotoBusy,coverPhotoBusy}=props;
 const name=profile?.display_name||seller.store_name;
 return <section className="market-seller-profile-page">
  <button className="market-back-button" onClick={onBack}><ArrowLeft size={16}/> Back to marketplace</button>
  <div className="market-public-profile">
   <div className="market-store-cover">{seller.cover_path?<img src={coverUrl} alt={seller.store_name+' cover'}/>:<div className="market-cover-placeholder">MARKIO · STUDENT BUSINESS</div>}</div>
   <div className="market-public-profile-main">
    <div className="market-public-avatar">{photoUrl?<img src={photoUrl} alt={name}/>:<span>{name.slice(0,1).toUpperCase()}</span>}</div>
    <div className="market-public-profile-copy">
     <span className="market-kicker">MARKIO SELLER PROFILE</span>
     <h1>{name}</h1>
     <p className="market-profile-handle">@{profile?.username||'student-seller'}</p>
     <h2>{seller.store_name}</h2>
     <p>{seller.description||'Student-owned business at Bells University.'}</p>
     <span className="seller-approved-label"><ShieldCheck size={14}/> Approved seller</span>
    </div>
   </div>
   {isOwner&&<div className="market-profile-actions">
    <button className="market-secondary" onClick={onEdit}><Settings size={15}/> Edit profile</button>
    <label className="market-secondary market-file-action"><Camera size={15}/> Change profile picture<input type="file" accept="image/jpeg,image/png,image/webp" disabled={profilePhotoBusy} onChange={onProfilePhoto}/></label>
    <label className="market-secondary market-file-action"><Camera size={15}/> Change cover photo<input type="file" accept="image/jpeg,image/png,image/webp" disabled={coverPhotoBusy} onChange={onCoverPhoto}/></label>
    <button className="market-secondary" onClick={onShare}><Share2 size={15}/> Share profile</button>
    <button className="market-secondary" onClick={onWhatsApp}><MessageCircle size={15}/> Share to WhatsApp</button>
   </div>}
  </div>
  <div className="market-section-head"><div><span className="market-kicker">STORE CATALOGUE</span><h2>Products and services</h2></div><Store size={18}/></div>
  {children}
 </section>;
}
