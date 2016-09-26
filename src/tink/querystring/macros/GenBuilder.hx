package tink.querystring.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import tink.macro.BuildCache;
import tink.typecrawler.Crawler;
import tink.typecrawler.FieldInfo;
import tink.typecrawler.Generator;

using tink.MacroApi;

class GenBuilder {
  var prim:Expr;
  var name:String;
  var pos:Position;
  
  var data:ComplexType;
  var buffer:ComplexType;
  
  var dataType:Type;
  var bufferType:Type;
  
  function new(name, rawType:Type, pos) {
    
    this.name = name;
    this.pos = pos;
    this.prim = macro @:pos(pos) buffer.add(prefix, data);
    
    this.dataType = 
      switch rawType.reduce() {
          
        case TFun([{ t: data }], buffer):
          
          this.bufferType = buffer;
          
          data;
          
        case data: 
                    
          this.bufferType = Context.getType('tink.querystring.Builder.DefaultBuffer');
          data;
      }
    
    this.data = dataType.toComplex();
    this.buffer = bufferType.toComplex();   
  }
  
  public function args():Array<String>
    return ['prefix', 'buffer', 'data'];
    
  public function nullable(e:Expr):Expr
    return macro @:pos(e.pos) if (data != null) $e;
    
  public function string():Expr
    return prim;
    
  public function float():Expr
    return prim;
    
  public function int():Expr
    return prim;
  
  public function bool():Expr
    return prim;
  
  public function dyn(e:Expr, ct:ComplexType):Expr
    return throw 'not implemented';
    
  public function dynAccess(e:Expr):Expr
    return throw 'not implemented';
    
  public function date():Expr
    return throw 'not implemented';
    
  public function bytes():Expr
    return throw 'not implemented';
    
  public function anon(fields:Array<FieldInfo>, ct:ComplexType):Function {
    
    function info(i:FieldInfo):Expr
      return macro @:pos(i.pos) {
        var prefix = switch prefix {
          case '': $v{i.name};
          case v: v + $v{'.'+i.name};
        }
        var data = ${['data', i.name].drill(i.pos)};
        ${i.expr};
      }
    
    var body = [for (f in fields) info(f)].toBlock();
    
    return (macro @:pos(pos) function (prefix:String, buffer:$buffer, data:$ct) $body).getFunction().sure();
  }
    
  public function array(e:Expr):Expr
    return (macro @:pos(e.pos) for (i in 0...data.length) {
      var data = data[i],
          prefix = prefix + '[' + i + ']';
      $e;
    });
    
  public function map(k:Expr, v:Expr):Expr
    return throw 'not implemented';
    
  public function enm(constructors:Array<EnumConstructor>, ct:ComplexType, pos:Position, gen:GenType):Expr
    return throw 'not implemented';
    
  public function rescue(t:Type, pos:Position, gen:GenType):Option<Expr>
    return throw 'not implemented';
    
  public function reject(t:Type):String
    return 'Unsupported type $t';
  
  function get() {
    var crawl = Crawler.crawl(dataType, pos, this);
    
    var bufName = switch buffer {
      case TPath(p): p;
      default: pos.error('unsupported buffer type');
    }
    
    var ret = macro class $name {
      
      public function new() {}
      
      public function stringify(data:$data) {
        var prefix = '',
            buffer = new $bufName();//TODO: consider making this a stack variable
        ${crawl.expr};
        return buffer.flush();
      }
      
    }
    
    ret.fields = ret.fields.concat(crawl.fields);
    
    return ret;    
  }  
  static function buildNew(ctx:BuildContext) 
    return new GenBuilder(ctx.name, ctx.type, ctx.pos).get();    
  
  static public function build() 
    return BuildCache.getType('tink.querystring.Builder', buildNew);

  
}