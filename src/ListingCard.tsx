import { useEffect, useRef, useState, type TouchEvent, type MouseEvent } from 'react';
import { Bookmark, MoreHorizontal, Pin, Share2, Trash2, ShoppingCart, Flag, MessageCircle } from 'lucide-react';

export type MarketplaceCardListing = {
  id:string; title:string; price_ngn:number; image_paths:string[]; availability:string;
  is_pinned?:boolean; store?:{store_name:string}|null;
};

type Props = {
  item:MarketplaceCardListing;
  imageUrl:string;
  saved:boolean;
  isOwner:boolean;
  money:(value:number)=>string;
  onOpen:()=>void;
  onSave:()=>void;
  onShare:()=>void;
  onAddToCart:()=>void;
  onReport:()=>void;
  onDelete:()=>void;
  onPin:()=>void;
  onOpenSeller:()=>void;
};

export default function ListingCard({item,imageUrl,saved,isOwner,money,onOpen,onSave,onShare,onAddToCart,onReport,onDelete,onPin,onOpenSeller}:Props){
  const [menuOpen,setMenuOpen]=useState(false);
  const menuRef=useRef<HTMLDivElement>(null);
  const timerRef=useRef<number|undefined>(undefined);
  const startRef=useRef<{x:number;y:number}|null>(null);
  const firedRef=useRef(false);
  const suppressClickRef=useRef(false);
  const clearTimer=()=>{if(timerRef.current!==undefined){window.clearTimeout(timerRef.current);timerRef.current=undefined}};
  const startPress=(event:TouchEvent<HTMLElement>)=>{
    if(event.touches.length!==1)return;
    const touch=event.touches[0];startRef.current={x:touch.clientX,y:touch.clientY};firedRef.current=false;
    clearTimer();
    timerRef.current=window.setTimeout(()=>{firedRef.current=true;suppressClickRef.current=true;setMenuOpen(true);},2500);
  };
  const movePress=(event:TouchEvent<HTMLElement>)=>{
    if(!startRef.current||event.touches.length!==1)return;
    const touch=event.touches[0];if(Math.abs(touch.clientX-startRef.current.x)>10||Math.abs(touch.clientY-startRef.current.y)>10)clearTimer();
  };
  const endPress=()=>{clearTimer();startRef.current=null;if(firedRef.current){window.setTimeout(()=>{suppressClickRef.current=false;},500)}};
  const handleContext=(event:MouseEvent<HTMLElement>)=>{event.preventDefault();setMenuOpen(true)};
  useEffect(()=>{if(!menuOpen)return;const close=(event:PointerEvent)=>{if(!menuRef.current?.contains(event.target as Node))setMenuOpen(false)};const key=(event:KeyboardEvent)=>{if(event.key==='Escape')setMenuOpen(false)};document.addEventListener('pointerdown',close);document.addEventListener('keydown',key);return()=>{document.removeEventListener('pointerdown',close);document.removeEventListener('keydown',key)}},[menuOpen]);
  useEffect(()=>()=>clearTimer(),[]);
  const act=(fn:()=>void)=>{setMenuOpen(false);fn()};
  const shareWhatsApp=()=>{const url=new URL('/',window.location.origin);url.searchParams.set('listing',item.id);const text=encodeURIComponent('Found this on MARKIO: '+item.title+' — '+money(item.price_ngn)+' '+url.toString());window.open('https://wa.me/?text='+text,'_blank','noopener,noreferrer')};
  return <article className="market-product listing-action-card" onTouchStart={startPress} onTouchMove={movePress} onTouchEnd={endPress} onTouchCancel={endPress} onContextMenu={handleContext}>
    <button className="market-product-image" onClick={()=>{if(suppressClickRef.current)return;onOpen()}} aria-label={'View '+item.title}>
      {imageUrl?<img src={imageUrl} alt={item.title}/>:<span className="product-placeholder">No image</span>}
      <span className={'availability '+(item.availability==='available'?'':'muted')}>{item.availability==='available'?'Available':item.availability}</span>
      {item.is_pinned&&<span className="listing-pinned-label"><Pin size={11}/> Pinned</span>}
    </button>
    <button className="save-product" onClick={onSave} aria-label={saved?'Remove saved listing':'Save listing'}><Bookmark size={16} fill={saved?'currentColor':'none'}/></button>
    <button className="listing-more-button" onClick={()=>setMenuOpen(v=>!v)} aria-label="Listing actions" aria-expanded={menuOpen}><MoreHorizontal size={18}/></button>
    <button className="product-copy" onClick={()=>{if(suppressClickRef.current)return;onOpen()}}><strong>{item.title}</strong><b>{money(item.price_ngn)}</b><small>{item.store?.store_name||'Student seller'}</small></button>
    {item.store&&<button className="market-store-link" onClick={onOpenSeller}>View store <span aria-hidden>→</span></button>}
    {menuOpen&&<div className="listing-context-menu" ref={menuRef} role="menu" aria-label="Listing actions">
      {isOwner?<><button role="menuitem" onClick={()=>act(onPin)}><Pin size={15}/>{item.is_pinned?'Unpin listing':'Pin listing'}</button><button role="menuitem" onClick={()=>act(shareWhatsApp)}><MessageCircle size={15}/>Share to WhatsApp</button><button role="menuitem" onClick={()=>act(onShare)}><Share2 size={15}/>Share listing</button><button role="menuitem" className="danger" onClick={()=>act(onDelete)}><Trash2 size={15}/>Delete listing</button></>:<><button role="menuitem" onClick={()=>act(onAddToCart)}><ShoppingCart size={15}/>Add to cart</button><button role="menuitem" onClick={()=>act(shareWhatsApp)}><MessageCircle size={15}/>Share to WhatsApp</button><button role="menuitem" onClick={()=>act(onShare)}><Share2 size={15}/>Share listing</button><button role="menuitem" onClick={()=>act(onReport)}><Flag size={15}/>Report listing</button></>}
    </div>}
  </article>;
}
