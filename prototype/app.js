const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const scrim=$("#scrim"),addSheet=$("#add-sheet"),formSheet=$("#form-sheet"),toast=$("#toast");
const STORE="ujexa_health_stage06_demo_records";
let records=[];
try{records=JSON.parse(localStorage.getItem(STORE)||"[]");if(!Array.isArray(records))records=[];}catch{records=[];}
const escapeHtml=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const closeAll=()=>{scrim.classList.remove("open");addSheet.classList.remove("open");formSheet.classList.remove("open")};
function openAdd(){scrim.classList.add("open");addSheet.classList.add("open")}
function notify(msg){toast.textContent=msg;toast.classList.add("show");setTimeout(()=>toast.classList.remove("show"),2400)}
function persist(){localStorage.setItem(STORE,JSON.stringify(records));renderRecent();renderDashboardMetrics();}
$("#open-add").onclick=openAdd;$("#nav-add").onclick=openAdd;$("#close-sheet").onclick=closeAll;scrim.onclick=closeAll;
const templates={
 vitals:["Log vitals",[["Measurement","select",["Blood pressure","Heart rate","Blood glucose","Temperature","Oxygen saturation","Weight"]],["Value","text"],["Unit","text"],["Date and time","datetime-local"]]],
 checkup:["Log checkup",[["Visit type","select",["Routine checkup","Consultation","Screening","Follow-up","Urgent visit","Other"]],["Visit date","date"],["Clinician / provider","text"],["Facility","text"],["Reason for visit","textarea"],["Findings and notes","textarea"],["Follow-up date","date"]]],
 medication:["Add medication",[["Medication name","text"],["Strength / dose","text"],["Schedule","text"],["Start date","date"],["Notes","textarea"]]],
 symptoms:["Log symptoms",[["Symptom","text"],["Severity","select",["Mild","Moderate","Severe"]],["Started","datetime-local"],["Description","textarea"]]],
 note:["Add health note",[["Title","text"],["Note","textarea"]]],
 document:["Add medical document",[["Document name","text"],["Document type","select",["Lab result","Prescription","Discharge summary","Imaging report","Referral","Other"]],["Document date","date"],["File","file"]]],
 appointment:["Add appointment",[["Appointment","text"],["Provider / facility","text"],["Date and time","datetime-local"],["Reason","textarea"]]],
 meal:["Log meal",[["Meal","select",["Breakfast","Lunch","Dinner","Snack"]],["Description","text"],["Time","datetime-local"]]],
 activity:["Log activity",[["Activity","text"],["Duration (minutes)","number"],["Notes","textarea"]]],
 sleep:["Log sleep",[["Sleep duration","text"],["Bedtime","datetime-local"],["Wake time","datetime-local"],["Quality","select",["Poor","Fair","Good","Excellent"]]]]
};
function fieldMarkup([label,type,opts]){let id="f"+Math.random().toString(36).slice(2,8);let el=type==="select"?`<select id="${id}" name="${label}">${opts.map(x=>`<option>${escapeHtml(x)}</option>`).join("")}</select>`:type==="textarea"?`<textarea id="${id}" name="${label}" rows="3" placeholder="Add details…"></textarea>`:`<input id="${id}" name="${label}" type="${type}" ${type==="file"?"accept='.pdf,image/*'":""} placeholder="Enter ${escapeHtml(label.toLowerCase())}" ${type==="file"?"":""}>`;return `<div class="field"><label for="${id}">${escapeHtml(label)}</label>${el}</div>`}
function openForm(key){closeAll();let [title,fields]=templates[key]||["Add record",[["Details","textarea"]]];$("#form-title").textContent=title;$("#form-fields").innerHTML=fields.map(fieldMarkup).join("");$("#record-form").dataset.kind=key;scrim.classList.add("open");formSheet.classList.add("open")}
$$("[data-action]").forEach(b=>b.addEventListener("click",()=>openForm(b.dataset.action)));
$("#close-form").onclick=closeAll;$("#cancel-form").onclick=closeAll;
$("#record-form").addEventListener("submit",e=>{e.preventDefault();let kind=e.currentTarget.dataset.kind;let fd=new FormData(e.currentTarget),data={};for(const [k,v] of fd.entries()){if(v instanceof File){if(v.name)data[k]=`File selected: ${v.name} (not stored)`;}else if(String(v).trim())data[k]=String(v).trim();}
 if(!Object.keys(data).length){notify("Add at least one detail before saving.");return;}
 const record={id:crypto.randomUUID?.()||String(Date.now()),kind,title:templates[kind]?.[0]||"Health record",data,createdAt:new Date().toISOString(),provenance:"Patient-entered · Unverified"};
 records.unshift(record);try{persist();closeAll();notify(`${record.title} saved on this device.`);}catch(err){records.shift();notify("Could not save. Device storage may be full.");}e.currentTarget.reset();});
function recordSummary(r){const vals=Object.entries(r.data).filter(([k])=>k!=="File").slice(0,2).map(([k,v])=>`${k}: ${v}`);return vals.join(" · ")||"No details";}
function renderRecent(){const target=$(".recent");if(!target)return;let old=target.querySelector(".recent-list");if(!old){old=document.createElement("div");old.className="recent-list";target.append(old);}old.innerHTML=records.slice(0,4).map(r=>`<div class="recent-row"><span class="recent-icon">✧</span><div><b>${escapeHtml(r.title)}</b><p class="muted small">${escapeHtml(new Date(r.createdAt).toLocaleString())} · ${escapeHtml(recordSummary(r))}</p></div><span class="status">Saved</span></div>`).join("")||'<p class="muted small">No patient-entered records yet. Add your first record to begin your timeline.</p>'; }
function renderDashboardMetrics(){const n=records.length;const p=$(".greeting .muted");if(p)p.textContent=`${n} patient-entered record${n===1?"":"s"} saved on this device.`;}
function setTab(tab){$$(".nav-item").forEach(n=>n.classList.toggle("active",n.dataset.tab===tab));$("#main").classList.toggle("hidden",tab!=="home");$("#secondary").classList.toggle("hidden",tab==="home");if(tab==="home")return;
 const panel=$("#secondary");
 if(tab==="records"){panel.innerHTML=`<div class="page-panel"><p class="eyebrow">YOUR HEALTH HISTORY</p><h1>Your records</h1><p class="muted">A private timeline of information you choose to record.</p><div class="record-list">${records.map(r=>`<article class="empty-card record-card"><div class="section-heading"><h3>${escapeHtml(r.title)}</h3><span class="status">Unverified</span></div><p class="muted small">${escapeHtml(new Date(r.createdAt).toLocaleString())}</p><p>${escapeHtml(recordSummary(r))}</p><p class="muted small">${escapeHtml(r.provenance)}</p><button class="text-btn" data-delete="${escapeHtml(r.id)}">Delete record</button></article>`).join("")||'<div class="empty-card"><div style="font-size:32px">✧</div><h3>Your timeline starts here</h3><p>Records you add will appear here, newest first.</p></div>'}</div><button class="btn primary" id="page-add">Add a health record</button></div>`;
 panel.querySelectorAll("[data-delete]").forEach(b=>b.onclick=()=>{if(confirm("Delete this local demo record?")){records=records.filter(r=>r.id!==b.dataset.delete);persist();setTab("records");notify("Record deleted from this device.");}});
 }else if(tab==="insights"){let counts={};records.forEach(r=>counts[r.kind]=(counts[r.kind]||0)+1);panel.innerHTML=`<div class="page-panel"><p class="eyebrow">YOUR DATA, MADE CLEAR</p><h1>Health insights</h1><p class="muted">Only summaries of records you have entered. No diagnosis or treatment recommendations.</p><div class="metrics insight-metrics"><div class="metric purple"><b>${records.length}</b><span>Total records</span></div>${Object.entries(counts).map(([k,v])=>`<div class="metric blue"><b>${v}</b><span>${escapeHtml(k)}</span></div>`).join("")}</div><div class="empty-card"><h3>${records.length?"Your activity so far":"Insights grow with your records"}</h3><p>${records.length?"These counts describe what you logged; they are not a clinical assessment.":"Add observations, checkups or medication records to build a personal history."}</p></div></div>`;}
 else {panel.innerHTML=`<div class="page-panel"><p class="eyebrow">CONTROL & PRIVACY</p><h1>Your profile</h1><div class="empty-card"><h3>Patient-owned by design</h3><p>Identity, emergency contacts, trusted devices and clinician sharing are planned for later secure integration.</p><p class="muted small">This browser prototype does not authenticate users, encrypt local records, or provide emergency access.</p><button class="btn secondary" id="clear-data">Clear local demo records</button></div></div>`;$("#clear-data").onclick=()=>{if(confirm("Permanently clear all Ujexa Health demo records stored in this browser?")){records=[];persist();setTab("profile");notify("Local demo records cleared.");}};}
 const add=$("#page-add");if(add)add.onclick=openAdd;
}
$$("[data-tab]").forEach(b=>b.addEventListener("click",()=>setTab(b.dataset.tab)));
$("#notifications").onclick=()=>notify("You’re all caught up.");$(".avatar").onclick=()=>setTab("profile");
document.addEventListener("keydown",e=>{if(e.key==="Escape")closeAll()});
renderRecent();renderDashboardMetrics();
