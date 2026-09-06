const colors={Applications:'#c49af0',Documents:'#89a8f5',Images:'#ef86ad',Videos:'#ffb454',Audio:'#ed8796',Archives:'#eed49f',Code:'#8aadf4',Temporary:'#a5adcb',Other:'#6e738d',Folders:'#8aadf4'};
const marks={Applications:'[A]',Documents:'[D]',Images:'[I]',Videos:'[V]',Audio:'[M]',Archives:'[Z]',Code:'[C]',Temporary:'[T]',Other:'[?]',Folders:'[+]'};
const state={files:[],folders:[],categories:{},capacity:{total:0,used:0,free:0},root:'',view:'all',category:'All',query:'',selected:null,selectedIndex:0,scanning:false};
const $=id=>document.getElementById(id);
const bridge=command=>window.webkit?.messageHandlers?.spacelens?.postMessage(JSON.stringify(typeof command==='string'?{command}:command));
function size(bytes){if(!Number.isFinite(bytes))return '--';const units=['B','KiB','MiB','GiB','TiB'];let n=bytes,u=0;while(n>=1024&&u<units.length-1){n/=1024;u++}return `${n.toFixed(u===0?0:n>=100?0:n>=10?1:2)} ${units[u]}`}
function shortPath(path){return path?path.replace(/^\/home\/[^/]+/,'~'):''}
function escapeHtml(value){return String(value??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]))}
function toast(message){const el=$('toast');el.textContent=message;el.classList.add('visible');clearTimeout(toast.timer);toast.timer=setTimeout(()=>el.classList.remove('visible'),1800)}

function renderCategories(){
  const nav=$('categoryNav');nav.innerHTML='';
  Object.keys(colors).filter(x=>x!=='Folders').forEach(category=>{
    const button=document.createElement('button');
    button.className=`tree-row ${state.category===category?'selected':''}`;
    button.innerHTML=`<i class="type-mark" style="background:${colors[category]}"></i><b>${category.toUpperCase()}</b><em>${size(state.categories[category]||0)}</em>`;
    button.onclick=()=>{state.category=state.category===category?'All':category;state.view='all';state.selected=null;state.selectedIndex=0;render()};
    nav.append(button);
  });
}

function renderStorage(){
  const c=state.capacity,total=Math.max(c.total,1),used=c.used||0;
  $('usedSize').textContent=size(used);$('totalSize').textContent=size(c.total);$('freeSize').textContent=size(c.free);$('percentFull').textContent=`${Math.round(used/total*100)}%`;$('rootPath').textContent=shortPath(state.root)||'~';
  const bar=$('storageBar'),legend=$('categoryLegend');bar.innerHTML='';legend.innerHTML='';
  Object.entries(state.categories).filter(([,value])=>value>0).sort((a,b)=>b[1]-a[1]).forEach(([category,value])=>{
    const part=document.createElement('i');part.style.width=`${Math.max(value/total*100,.4)}%`;part.style.background=colors[category]||colors.Other;part.title=`${category}: ${size(value)}`;bar.append(part);
    const label=document.createElement('span');label.innerHTML=`<i style="background:${colors[category]||colors.Other}"></i>${category.toUpperCase()} ${size(value)}`;legend.append(label);
  });
  const rest=document.createElement('i');rest.className='bar-empty';bar.append(rest);
}

function currentItems(){
  let items=state.view==='folders'?state.folders:state.files;
  if(state.category!=='All'&&state.view!=='folders')items=items.filter(item=>item.category===state.category);
  if(state.query){const q=state.query.toLowerCase();items=items.filter(item=>`${item.name} ${item.path}`.toLowerCase().includes(q))}
  return items;
}

function selectIndex(index,scroll=true){
  const items=currentItems();if(!items.length){state.selected=null;state.selectedIndex=0;renderDetails();return}
  state.selectedIndex=Math.max(0,Math.min(index,items.length-1));state.selected=items[state.selectedIndex];
  document.querySelectorAll('#fileRows tr').forEach((row,i)=>row.classList.toggle('selected',i===state.selectedIndex));
  if(scroll)document.querySelector(`#fileRows tr:nth-child(${state.selectedIndex+1})`)?.scrollIntoView({block:'nearest'});
  renderDetails();
}

function renderTable(){
  const items=currentItems(),maxSize=Math.max(items[0]?.size||1,1);
  $('viewTitle').textContent=state.view==='folders'?'FOLDERS':state.category==='All'?'ALL FILES':state.category.toUpperCase();
  $('itemSummary').textContent=`${items.length.toLocaleString()} ENTRIES // SIZE DESC`;$('emptyState').classList.toggle('visible',!items.length);
  const rows=$('fileRows');rows.innerHTML='';
  items.forEach((item,index)=>{
    const row=document.createElement('tr');row.tabIndex=-1;row.className=index===state.selectedIndex?'selected':'';
    const usage=Math.max(item.size/maxSize*100,.5);
    const nameCell=document.createElement('td');
    const fileCell=document.createElement('div');fileCell.className='file-cell';
    const prefix=document.createElement('span');prefix.className='file-prefix';prefix.textContent=marks[item.category]||marks.Other;
    const copy=document.createElement('span');copy.className='file-copy';
    const name=document.createElement('b');name.className='file-name';name.textContent=item.name;name.title=item.name;
    const kind=document.createElement('small');kind.className='file-kind';kind.textContent=item.kind||'File';
    copy.append(name,kind);fileCell.append(prefix,copy);nameCell.append(fileCell);
    const pathCell=document.createElement('td');pathCell.textContent=shortPath(item.path);pathCell.title=item.path;
    const modifiedCell=document.createElement('td');modifiedCell.textContent=item.modified;
    const sizeCell=document.createElement('td');sizeCell.className='right size';sizeCell.textContent=size(item.size);
    const usageCell=document.createElement('td');const meter=document.createElement('span');meter.className='mini-bar';
    const fill=document.createElement('span');fill.style.width=`${usage}%`;meter.append(fill);usageCell.append(meter);
    row.append(nameCell,pathCell,modifiedCell,sizeCell,usageCell);
    row.onclick=()=>selectIndex(index,false);row.ondblclick=()=>bridge({command:'open-path',path:item.path});rows.append(row);
  });
  if(items.length)selectIndex(Math.min(state.selectedIndex,items.length-1),false);else renderDetails();
}

function renderDetails(){
  const item=state.selected,panel=$('detailPanel');
  if(!item){panel.innerHTML='<div class="panel-title"><span>┌─ INSPECTOR</span><span>─┐</span></div><div class="empty-detail"><span>[ -- ]</span><b>NO ENTRY SELECTED</b><small>use ↑/↓ or j/k</small></div>';return}
  const percent=state.capacity.used?item.size/state.capacity.used*100:0;
  panel.innerHTML=`<div class="panel-title"><span>┌─ INSPECTOR</span><span>─┐</span></div><div class="inspect-content"><div class="inspect-icon" style="color:${colors[item.category]||colors.Other}">${marks[item.category]||marks.Other}</div><p class="inspect-label">ENTRY NAME</p><h2>${escapeHtml(item.name)}</h2><p class="inspect-path">${escapeHtml(shortPath(item.path))}</p><div class="inspect-size"><strong>${size(item.size)}</strong><small>${percent.toFixed(percent<.1?2:1)}% OF USED DISK</small></div><dl><div><dt>TYPE</dt><dd>${escapeHtml(item.kind)}</dd></div><div><dt>GROUP</dt><dd>${escapeHtml(item.category).toUpperCase()}</dd></div><div><dt>MODIFIED</dt><dd>${escapeHtml(item.modified)}</dd></div><div><dt>INDEX</dt><dd>${String(state.selectedIndex+1).padStart(4,'0')}</dd></div></dl><button id="openSelected" class="inspect-open">[ENTER] OPEN LOCATION</button></div>`;
  $('openSelected').onclick=()=>bridge({command:'open-path',path:item.path});
}

function render(){
  renderCategories();renderStorage();renderTable();
  document.querySelectorAll('[data-view]').forEach(button=>button.classList.toggle('active',button.dataset.view===state.view));
}
function setScanning(value){state.scanning=value;$('scanProgress').classList.toggle('visible',value)}

window.SpaceLens={receive(message){
  const {event,payload}=message;
  if(event==='scan-start'){
    state.root=payload.root;state.selected=null;state.selectedIndex=0;setScanning(true);$('progressTitle').textContent='INDEXING FILESYSTEM';$('progressDetail').textContent=shortPath(payload.root);renderStorage();
  }else if(event==='scan-progress'){
    $('progressDetail').textContent=`${payload.files.toLocaleString()} FILES // ${size(payload.bytes)} // ${shortPath(payload.current)}`;$('fileCount').textContent=payload.files.toLocaleString();$('folderCount').textContent=payload.folders.toLocaleString();
  }else if(event==='scan-complete'){
    Object.assign(state,payload);state.selectedIndex=0;state.selected=payload.files[0]||payload.folders[0]||null;setScanning(false);$('fileCount').textContent=payload.fileCount.toLocaleString();$('folderCount').textContent=payload.folderCount.toLocaleString();$('reclaimSize').textContent=size(payload.categories.Temporary||0);$('errorCount').textContent=payload.errors.toLocaleString();render();
  }else if(event==='cancelled'){setScanning(false);toast('SCAN ABORTED')}
  else if(event==='scan-error'){setScanning(false);toast(payload.message.toUpperCase())}
}};

document.querySelectorAll('[data-command]').forEach(button=>button.onclick=()=>bridge(button.dataset.command));
document.querySelectorAll('[data-view]').forEach(button=>button.onclick=()=>{state.view=button.dataset.view;state.category='All';state.selected=null;state.selectedIndex=0;render()});
$('searchInput').oninput=event=>{state.query=event.target.value;state.selectedIndex=0;state.selected=null;renderTable()};
document.addEventListener('keydown',event=>{
  const input=document.activeElement===$('searchInput');
  if(!input&&(event.key==='j'||event.key==='ArrowDown')){event.preventDefault();selectIndex(state.selectedIndex+1)}
  else if(!input&&(event.key==='k'||event.key==='ArrowUp')){event.preventDefault();selectIndex(state.selectedIndex-1)}
  else if(!input&&event.key==='/'){event.preventDefault();$('searchInput').focus()}
  else if(!input&&event.key.toLowerCase()==='r')bridge('scan-home')
  else if(!input&&event.key.toLowerCase()==='s')bridge('scan-root')
  else if(!input&&event.key.toLowerCase()==='o')bridge('choose-folder')
  else if(!input&&event.key==='Enter'&&state.selected)bridge({command:'open-path',path:state.selected.path})
  else if(event.key==='Escape'){if(state.scanning)bridge('cancel-scan');else{state.query='';$('searchInput').value='';$('searchInput').blur();renderTable()}}
});
