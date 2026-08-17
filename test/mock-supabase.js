/* Stand-in for @supabase/supabase-js used only by test/index.html.
   Implements just enough of the client surface that index.html touches,
   backed by an in-memory store, so the ONLINE code path can be driven
   in a browser without a real project. */
(function(){
  const DB = { monthly_input:[], payment_tracker:[], escalations:[], action_tracker:[], vendor_performance:[] };
  window.__DB = DB;
  let seq = 0;
  const uuid = () => 'test-' + (++seq);

  function Builder(table){
    this.table = table; this.op = 'select'; this.payload = null;
    this.filters = []; this.wantRows = false;
  }
  Builder.prototype.select = function(){ this.wantRows = true; return this; };
  Builder.prototype.order  = function(){ return this; };
  Builder.prototype.limit  = function(){ return this; };
  Builder.prototype.insert = function(row){ this.op='insert'; this.payload=row; this.wantRows=false; return this; };
  Builder.prototype.update = function(row){ this.op='update'; this.payload=row; this.wantRows=false; return this; };
  Builder.prototype.delete = function(){ this.op='delete'; return this; };
  Builder.prototype.eq     = function(c,v){ this.filters.push([c,v]); return this; };

  Builder.prototype.run = function(){
    const rows = DB[this.table];
    if(!rows) return { data:null, error:{ message:'relation "'+this.table+'" does not exist' } };
    const match = r => this.filters.every(([c,v]) => r[c] === v);
    if(this.op === 'select') return { data: rows.slice(), error:null };
    if(this.op === 'insert'){
      const row = Object.assign({ id: uuid() }, this.payload);
      rows.push(row);
      return { data: this.wantRows ? [row] : null, error:null };
    }
    if(this.op === 'update'){
      const hit = rows.filter(match);
      hit.forEach(r => Object.assign(r, this.payload));
      return { data: this.wantRows ? hit : null, error:null };
    }
    if(this.op === 'delete'){
      const keep = rows.filter(r => !match(r));
      DB[this.table] = keep;
      return { data:null, error:null };
    }
  };
  Builder.prototype.then = function(res, rej){
    return Promise.resolve().then(() => this.run()).then(res, rej);
  };

  window.supabase = {
    createClient(){
      return {
        from: t => new Builder(t),
        channel: () => ({ on(){ return this }, subscribe(){ return this } })
      };
    }
  };
})();
