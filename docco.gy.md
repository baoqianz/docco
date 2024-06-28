Docco
=====

**Docco** is a quick-and-dirty documentation generator, rewritten in
[Groovy](https://groovy-lang.org), [which](https://github.com/jashkenas/docco)
is originally implemented in [Literate CoffeeScript](http://coffeescript.org/#literate).
It produces an HTML document that displays your comments intermingled with your
code. All prose is passed through
[Markdown](http://daringfireball.net/projects/markdown/syntax), and code is
passed through [Highlight.js](https://github.com/Sayi/Highlight.java)
syntax highlighting.
This page is the result of running Docco against its own
[source file](https://github.com/baoqianz/docco/blob/master/docco.gy.md).

    @Grapes([
      @Grab("org.commonmark:commonmark:0.22.0"),
      @Grab("com.deepoove:codehighlight:1.0.3"),
    ])
    
    import com.codewaves.codehighlight.core.Highlighter
    import com.codewaves.codehighlight.core.Keyword
    import com.codewaves.codehighlight.core.Language
    import com.codewaves.codehighlight.core.Mode
    import com.codewaves.codehighlight.core.StyleRenderer
    import com.codewaves.codehighlight.core.StyleRendererFactory
    import com.codewaves.codehighlight.languages.LanguageBuilder
    import com.codewaves.codehighlight.renderer.HtmlRenderer
    import groovy.ant.AntBuilder
    import groovy.cli.commons.CliBuilder
    import groovy.json.JsonOutput
    import groovy.json.JsonSlurper
    import groovy.text.StreamingTemplateEngine
    import groovy.transform.CompileStatic
    import groovy.util.logging.Log
    import java.lang.invoke.MethodHandles
    import java.util.concurrent.CompletableFuture
    import org.codehaus.groovy.runtime.DefaultGroovyMethods
    import org.codehaus.groovy.runtime.InvokerHelper
    import org.commonmark.parser.Parser
    import org.commonmark.renderer.html.HtmlRenderer as MarkdownHtmlRenderer
    
    class DoccoMain extends Script {
      static void main(String[] args) {
        InvokerHelper.runScript(DoccoMain.class, args)
      }
    
      def before() {
        DefaultGroovyMethods.metaClass.static.filter = DefaultGroovyMethods::grep
        invokeMethod = { String name, Object[] args -> DefaultGroovyMethods."$name"(delegate, *args) }
        filter = invokeMethod.curry("filter")
        String[].metaClass.filter = filter
        List.metaClass.filter = filter
        tasks = []
      }
      
      def after() {
        for (def i = 0; i < tasks.size(); i++) {
          tasks[i].join()
        }
      }
    
      def run(args = args) {
        before()
        o = new Docco(args: args, tasks: tasks)
        o.run()
        after()
        this.exports = [
          run: o::run,
          document: o::document,
          parse: o::parse,
          format: o::format,
          version: o.version,
          thisScript: this,
        ]
      }
    
      @CompileStatic
      class ECMAScript {
        static final String IDENT_RE = '[A-Za-z$_][0-9A-Za-z$_]*'
        static final String[] KEYWORDS = [
          "as", // for exports
          "in",
          "of",
          "if",
          "for",
          "while",
          "finally",
          "var",
          "new",
          "function",
          "do",
          "return",
          "void",
          "else",
          "break",
          "catch",
          "instanceof",
          "with",
          "throw",
          "case",
          "default",
          "try",
          "switch",
          "continue",
          "typeof",
          "delete",
          "let",
          "yield",
          "const",
          "class",
          // JS handles these with a special rule
          // "get",
          // "set",
          "debugger",
          "async",
          "await",
          "static",
          "import",
          "from",
          "export",
          "extends"
        ]
        static final String[] LITERALS = [
          "true",
          "false",
          "null",
          "undefined",
          "NaN",
          "Infinity"
        ]
        static final String[] TYPES = [
          // Fundamental objects
          "Object",
          "Function",
          "Boolean",
          "Symbol",
          // numbers and dates
          "Math",
          "Date",
          "Number",
          "BigInt",
          // text
          "String",
          "RegExp",
          // Indexed collections
          "Array",
          "Float32Array",
          "Float64Array",
          "Int8Array",
          "Uint8Array",
          "Uint8ClampedArray",
          "Int16Array",
          "Int32Array",
          "Uint16Array",
          "Uint32Array",
          "BigInt64Array",
          "BigUint64Array",
          // Keyed collections
          "Set",
          "Map",
          "WeakSet",
          "WeakMap",
          // Structured data
          "ArrayBuffer",
          "SharedArrayBuffer",
          "Atomics",
          "DataView",
          "JSON",
          // Control abstraction objects
          "Promise",
          "Generator",
          "GeneratorFunction",
          "AsyncFunction",
          // Reflection
          "Reflect",
          "Proxy",
          // Internationalization
          "Intl",
          // WebAssembly
          "WebAssembly"
        ]
        static final String[] ERROR_TYPES = [
          "Error",
          "EvalError",
          "InternalError",
          "RangeError",
          "ReferenceError",
          "SyntaxError",
          "TypeError",
          "URIError"
        ]
        static final String[] BUILT_IN_GLOBALS = [
          "setInterval",
          "setTimeout",
          "clearInterval",
          "clearTimeout",
        
          "require",
          "exports",
        
          "eval",
          "isFinite",
          "isNaN",
          "parseFloat",
          "parseInt",
          "decodeURI",
          "decodeURIComponent",
          "encodeURI",
          "encodeURIComponent",
          "escape",
          "unescape"
        ]
        static final String[] BUILT_IN_VARIABLES = [
          "arguments",
          "this",
          "super",
          "console",
          "window",
          "document",
          "localStorage",
          "sessionStorage",
          "module",
          "global" // Node.js
        ]
        static final String[] BUILT_INS =
          BUILT_IN_GLOBALS +
          TYPES +
          ERROR_TYPES
      }
      
      @CompileStatic
      class CoffeescriptLanguage implements LanguageBuilder {
        private static String[] ALIASES = ['coffee']
        private static String IDENT_RE = '[A-Za-z$_][0-9A-Za-z$_]*'
        private static String POSSIBLE_PARAMS_RE = '(\\(.*\\)\\s*)?\\B[-=]>'
        private static String[] KEYWORDS_COFFEE = [
          'then',
          'unless',
          'until',
          'loop',
          'by',
          'when',
          'and',
          'or',
          'is',
          'isnt',
          'not'
        ]
        private static String[] KEYWORDS_NOT_VALID = [
          "var",
          "const",
          "let",
          "function",
          "static"
        ]
        private static String[] BUILT_INS = [
          'npm',
          'print'
        ]
        private static String[] LITERALS = [
          'yes',
          'no',
          'on',
          'off'
        ]
        private static Keyword[] KEYWORDS = new Keyword[] {
          new Keyword("keyword",  ECMAScript.KEYWORDS  + KEYWORDS_COFFEE - KEYWORDS_NOT_VALID),
          new Keyword("built_in", ECMAScript.BUILT_INS + BUILT_INS),
          new Keyword("literal",  ECMAScript.LITERALS  + LITERALS)
        }
        private static Mode SUBST  =
          new Mode().className("subst").begin("#\\{").end("\\}").keywords(KEYWORDS)
      
        private static Mode NUMBER =
          Mode.inherit(Mode.C_NUMBER_MODE, new Mode().starts(new Mode().end("(\\s*/)?").relevance(0)))
      
        private static Mode QUOTE_STRING =
          new Mode().className("string").begin('"').end('"').contains(new Mode[] {
            Mode.BACKSLASH_ESCAPE,
            SUBST,
          })
        private static Mode TRIPLE_APOS_STRING =
          new Mode().className("string").begin("'''").end("'''").contains(new Mode[] {
            Mode.BACKSLASH_ESCAPE,
          })
        private static Mode TRIPLE_QUOTE_STRING =
          new Mode().className("string").begin('"""').end('"""').contains(new Mode[] {
            Mode.BACKSLASH_ESCAPE,
            SUBST,
          })
        private static Mode STRING =
          new Mode().className("string").variants(new Mode[] {
            Mode.APOS_STRING_MODE,
            QUOTE_STRING,
            TRIPLE_APOS_STRING,
            TRIPLE_QUOTE_STRING,
          })
        private static Mode REGEXP =
          new Mode().className("regexp").variants(new Mode[] {
            new Mode().begin('///').end('///').contains(new Mode[] {
              SUBST,
              Mode.HASH_COMMENT_MODE,
            }),
            new Mode().begin("//[gim]{0,3}(?!\\w)").relevance(0),
            new Mode().begin(/\/(?![ *]).*?(?![\\]).\/[gim]{0,3}(?!\w)/)
          })
        private static Mode SUBLANG =
          new Mode().subLanguage("javascript").excludeBegin().excludeEnd().variants(new Mode[] {
            new Mode().begin("```").end("```"),
            new Mode().begin("`").end("`"),
          })
        private static Mode[] EXPRESSIONS = new Mode[] {
          Mode.BINARY_NUMBER_MODE,
          NUMBER,
          STRING,
          REGEXP,
          new Mode().begin("@" + IDENT_RE),
          SUBLANG,
        }
        private static Mode TITLE_MODE =
          Mode.inherit(Mode.TITLE_MODE, new Mode().begin(IDENT_RE))
      
        private static Mode PARAMS_MODE =
          new Mode().className("params").begin('\\([^\\(]').returnBegin().contains(new Mode[] {
            new Mode().begin('\\(').end('\\)').keywords(KEYWORDS).contains(EXPRESSIONS + [
              Mode.SELF,
            ])
          })
        private static Mode FUNCTION = new Mode()
          .className("function")
          .begin('^\\s*' + IDENT_RE + '\\s*=\\s*' + POSSIBLE_PARAMS_RE)
          .end('[-=]>')
          .returnBegin()
          .contains(new Mode[] {
            TITLE_MODE,
            PARAMS_MODE,
          })
        private static Mode FUNCTION_ANONYM =
          new Mode().begin(/[:\(,=]\s*/).relevance(0).contains(new Mode[] {
            new Mode().className("function").begin(POSSIBLE_PARAMS_RE).end("[-=]>").contains(new Mode[] {
              PARAMS_MODE,
            }).returnBegin()
          })
        private static Mode CLASS_DEFINITION = new Mode()
          .className("class")
          .beginKeywords(new Keyword[] { new Keyword("", "class") })
          .end('$')
          .illegal(/[:=${'"'}\[\]]/)
          .contains(new Mode[] {
            TITLE_MODE,
            new Mode()
              .beginKeywords(new Keyword[] { new Keyword("", "extends") })
              .endsWithParent()
              .illegal(/[:=${'"'}\[\]]/)
              .contains(new Mode[] { TITLE_MODE }),
          })
        private static Mode LABEL =
          new Mode().begin(IDENT_RE + ":").end(":").returnBegin().returnEnd().relevance(0)
      
        static {
          SUBST.contains(EXPRESSIONS)
        }
      
        Language build() {
          (Language) new Language()
            .aliases(ALIASES)
            .keywords(KEYWORDS)
            .contains(EXPRESSIONS + [
              Mode.HASH_COMMENT_MODE,
              Mode.COMMENT('###', '###', null),
              FUNCTION,
              FUNCTION_ANONYM,
              CLASS_DEFINITION,
              LABEL,
            ])
            .illegal(/\/\*/)
        }
      }
      
      @CompileStatic
      class Utils {
        static void setProperty(Class clazz, obj, String property, value) {
          def field = clazz.getDeclaredField(property)
          field.setAccessible(true)
      
          def MH = MethodHandles.lookup().unreflectSetter(field)
          obj == null ?
            MH.invokeWithArguments(value) :
            MH.invokeWithArguments(obj, value)
        }
      }
      
      class FS {
        def antBuilder = new AntBuilder()
      
        def mkdirs(path, k) {
          tasks << CompletableFuture.runAsync(() -> {
            new File(path).mkdirs()
          }).thenRun(() -> {
            k()
          })
        }
      
        def mkdirsSync(path) {
          new File(path).mkdirs()
        }
      
        def copy(src, dest, k) {
          tasks << CompletableFuture.runAsync(() -> {
            new File(src).isFile() ?
            antBuilder.copy(tofile: dest, overwrite: true, file: src) :
            antBuilder.copy(todir:  dest, overwrite: true) { fileset(dir: src) }
          }).handle((buffer, error) -> {
            k(error)
          })
        }
      
        def readFile(path, k) {
          tasks << CompletableFuture.supplyAsync(() -> {
            new File(path).withReader { reader ->
              reader.text
            }
          }).handle((buffer, error) -> {
            k(error, buffer)
          })
        }
      
        def readFileSync(path) {
          new File(path).withReader { reader ->
            reader.text
          }
        }
      
        def outputFileSync(file, data) {
          antBuilder.concat(destfile: file, encoding: "UTF-8", "$data")
        }
      
        def existsSync(path) {
          new File(path ?: "").exists()
        }
      
        def path, tasks
      
        FS() {
          antBuilder.project.listeners[0].msgOutputLevel = 1
        }
      }
      
      class Path {
        def resolve(path) {
          new File(path).getAbsolutePath()
        }
      
        def relative(from, to) {
          new File(from).toPath().relativize(new File(to).toPath()).toFile().getPath() ?: "."
        }
      
        def dirname(path) {
          def path0 = new File(path).getPath()
          new File(path0.substring(0, path0.size() - basename(path0).size()) ?: ".").getPath()
        }
      
        def basename(path) {
          new File(path ?: "").getName()
        }
      
        def basename(path, ext) {
          def base = basename(path)
          if (ext && base.endsWith(ext)) {
            base.substring(0, base.size() - ext.size())
          } else {
            base
          }
        }
      
        def extname(path) {
          def dot = path.lastIndexOf(".")
          def slash = path.lastIndexOf("/")
          def backslash = path.lastIndexOf("\\")
          if (backslash > slash) slash = backslash
          if (dot > slash + 1) {
            path.substring(dot)
          } else {
            ""
          }
        }
      
        def join(base, sub) {
          new File(base, sub).toPath().normalize().toFile().getPath()
        }
      
        def join(String... paths) {
          switch (paths.length) {
            case 0:
              "."
              break
            case 1:
              paths[0]
              break
            default:
              paths[1] = join(paths[0], paths[1])
              join(paths[1..-1] as String[])
          }
        }
      }
      
      class CommonMark {
        def parser = Parser.builder().build()
        def renderer = MarkdownHtmlRenderer.builder().build()
        def apply(String md) {
          renderer.render(lexer(md))
        }
      
        def lexer(String md) {
          parser.parse(md)
        }
      
        def setOptions(HashMap options) {
          // TODO: inline code block highlighting
        }
      }
      
      class HighlightJS {
        def highlighter = new Highlighter<CharSequence>(new RendererFactory());
        def getLanguage(String name) {
          Highlighter.findLanguage(name)
        }
      
        def highlightAuto(String code, String[] languageSubset = null) {
          [value: highlighter.highlightAuto(code, languageSubset).getResult()]
        }
      
        def highlight(String code, HashMap options) {
          [value: highlighter.highlight(options.language, code).getResult()]
        }
      
        class RendererFactory implements StyleRendererFactory<CharSequence> {
          StyleRenderer<CharSequence> create(String languageName) {
            return new HtmlRenderer("hljs-");
          }
        }
      
        HighlightJS() {
          Highlighter.registerLanguage(
            "coffeescript",
            Highlighter.mLanguageMap,
            new CoffeescriptLanguage().build()
          )
          Utils.setProperty(
            Highlighter,
            null,
            "mLanguages",
            (String[])(Highlighter.mLanguages + new String[] { "coffeescript" })
          )
        }
      }
      
      class UnderScore {
        def t = new StreamingTemplateEngine()
        def find(list, Closure predicate) {
          list.find predicate
        }
      
        def filter(list, Closure predicate) {
          list.findAll predicate
        }
      
        def extend(destination, Object[] sources) {
          for (def source in sources) {
            destination += source
          }
          destination
        }
      
        def pick(HashMap object, String[] keys) {
          object.findAll { entry -> entry.key in keys }
        }
      
        def keys(HashMap object) {
          object.keySet() as String[]
        }
      
        def compose(Closure[] functions) {
          switch (functions.length) {
            case 0:
              { a -> a }
              break
            case 1:
              functions[0]
              break
            default:
              functions[1] = functions[0].compose functions[1]
              compose(functions[1..-1] as Closure[])
          }
        }
      
        def template(templateString) {
          t.createTemplate(templateString)::make
        }
      }
      
      class Json {
        def jsonSlurper = new JsonSlurper()
        def parse(String text) {
          jsonSlurper.parseText(text)
        }
      
        def stringify(object) {
          JsonOutput.toJson(object)
        }
      }
      
      class Commander {
        def cli     = new CliBuilder(stopAtNonOption: false)
        def options = null
      
        def getProperty(String name) {
          name == "args" ?
            options.@commandLine.args :
            options.getProperty(name)
        }
      
        def hasOption(String option) {
          options.@commandLine.hasOption(option)
        }
      
        def options() {
          _.keys(options.@savedTypeOptions).filter { key -> key !in ['help', 'version']}
        }
      
        def opts() {
          options().iterator().collectEntries { option -> [option, this."$option" ?: null] }
        }
      
        def version(version) {
          cli.V(longOpt: 'version', defaultValue: version, 'output the version number')
          this
        }
      
        def usage(description) {
          cli.usage  = description
          cli.header = "\nOptions:"
          cli.h(longOpt: 'help', 'display help for command')
          this
        }
      
        def option(flags, description, defaultOrConvert) {
          def optionFlags = splitFlags flags
          def argName = optionFlags.arg
          def argCount = argName ? 1 : -1
          def variableKey = defaultOrConvert instanceof Closure ? "convert" : "defaultValue"
          cli."$optionFlags.short"(
            [ longOpt: optionFlags.long,
              (variableKey): defaultOrConvert,
              args: argCount,
              argName: argName ],
            description)
          this
        }
      
        def parse(args) {
          options = cli.parse(args)
          if (!options || showInfo()) {
            exit()
          }
          options
        }
      
        def usage() {
          cli.usage()
        }
      
        def splitFlags(flags) {
          def match = flags =~ /.*?-([a-zA-Z])\b.+?--(\w{2,})(\W+([\w\s]+)\b)*.*/
          def shortFlag = match[0][1]
          def longFlag = match[0][2]
          def argName = match[0][4]
          [short: shortFlag, long: longFlag, arg: argName]
        }
      
        def showInfo() {
          if (hasOption("--help")) {
            usage()
            true
          } else if (hasOption("--version")) {
            version()
            true
          }
        }
      
        def version() {
          println(version)
        }
      
        def exit() {
          System.exit(0)
        }
      
        def _
      }
      
      @Log
      class Docco {
        def __dirname = new File("").getAbsolutePath()
        def _ = new UnderScore()
        def JSON = new Json()
        def fs   = new FS()
        def path = new Path()
        def highlightjs = new HighlightJS()
        def marked = new CommonMark()
        def commander = new Commander()
      
        def document(options = [:], k = null) {
          def config = configure options
      
          fs.mkdirs(config.output) { ->
      
            k ?= { error -> if (error) throw error }
            def copyAsset = { file, k0 ->
              if (!fs.existsSync(file)) return k0()
              fs.copy file, path.join(config.output, path.basename(file)), k0
            }
            def complete  = { ->
              copyAsset(config.css) { error ->
                if (error) return k(error)
                if (fs.existsSync(config.public)) return copyAsset(config.public, k)
                k()
              }
            }
      
            def files = config.sources.collect()
      
            def nextFile
            if (true) nextFile = { ->
              def source = files.pop()
              fs.readFile(source) { error, buffer ->
                if (error) return k(error)
      
                def code = buffer.toString()
                def sections = parse source, code, config
                format source, sections, config
                write source, sections, config
                files.size() ? nextFile() : complete()
              }
            }
      
            if (files.size()) nextFile()
          }
        }
      
        def parse(source, code, config = [:]) {
          def lines    = code.split "\n"
          def sections = []
          def lang     = getLanguage source, config
          def hasCode  = '', docsText = '', codeText = ''
      
          def save = { ->
            sections.add([docsText: docsText, codeText: codeText])
            hasCode = docsText = codeText = ''
          }
      
          if (lang.literate) {
            def isText = true, maybeCode = true
            def match
            lines.eachWithIndex { line, i ->
              lines[i] = {switch (true) {
                case maybeCode && (match = line =~ /^([ ]{4}|[ ]{0,3}\t)/):
                  isText = false
                  line.substring(match[0][1].size())
                  break
                case maybeCode = line ==~ /^\s*$/:
                  isText ? lang.symbol : ""
                  break
                default:
                  isText = true
                  lang.symbol + ' ' + line
              }}()
            }
          }
      
          for (def line in lines) {
            switch (true) {
              case line =~ lang.commentMatcher && !(line =~ lang.commentFilter):
                if (hasCode) save()
                docsText += (line = line.replaceFirst(lang.commentMatcher, '')) + '\n'
                if (line ==~ /^(---+|===+)$/) save()
                break
              default:
                hasCode = true
                codeText += line + '\n'
            }
          }
          save()
      
          sections
        }
      
        def format(source, sections, config) {
          def language      = getLanguage source, config
          def markedOptions = [smartypants: true]
      
          if (config.marked) {
            markedOptions = config.marked
          }
      
          marked.setOptions markedOptions
          marked.setOptions([
            highlight: { code, lang ->
              lang ?= language.name
        
              if (highlightjs.getLanguage(lang)) {
                highlightjs.highlight(code, [language: lang]).value
              } else {
                log.info "docco: couldn't highlight code block with unknown language '#{lang}' in #{source}"
                code
              }
            }
          ])
      
          for (def section in sections) {
            def code
            code = highlightjs.highlight(section.codeText, [language: language.name]).value
            code = code.replaceFirst(/\s+$/, '')
            section.codeHtml = "<div class='highlight'><pre>${code}</pre></div>"
            section.docsHtml = marked.apply(section.docsText)
          }
        }
      
        def write(source, sections, config) {
          def first
      
          def destination = { file ->
            path.join(config.output, path.dirname(file), path.basename(file, path.extname(file)) + '.html')
          }
      
          def relative = { file ->
            def to = path.dirname(path.resolve(file))
            def from = path.dirname(path.resolve(destination(source)))
            path.join(path.relative(from, to), path.basename(file))
          }
      
          def firstSection = _.find sections, { section ->
            section.docsText.size() > 0
          }
          if (firstSection) first = marked.lexer(firstSection.docsText).firstChild
          def hasTitle = first && "$first.class" == "class org.commonmark.node.Heading" && first.level == 1
          def title = hasTitle ? first.firstChild.literal : path.basename(source)
          def css = relative path.join(config.output, path.basename(config.css))
      
          def html = config.template([
            sources: config.sources, css: css, title: title, hasTitle: hasTitle,
            sections: sections, path: path, destination: destination, relative: relative
          ])
      
          println "docco: ${source} -> ${destination source}"
          fs.outputFileSync destination(source), html
        }
      
        def defaults = [
          layout:     'parallel',
          output:     'docs',
          template:   null,
          css:        null,
          extension:  null,
          languages:  [:],
          marked:     null
        ]
      
        def configure(options) {
          def config = _.extend([:], defaults, _.pick(options.opts(), _.keys(defaults)))
      
          config.languages = buildMatchers config.languages
      
          if (options.template) {
            if (!options.css) {
              log.info "docco: no stylesheet file specified"
            }
            config.layout = null
          } else {
            def dir = config.layout = path.join __dirname, 'resources', config.layout
            if (fs.existsSync(path.join dir, 'public')) {
              config.public         = path.join dir, 'public'
            }
            config.template         = path.join dir, 'docco.jst'
            config.css              = options.css ?: path.join(dir, 'docco.css')
          }
          config.template = _.template fs.readFileSync(config.template)
      
          if (options.marked) {
            config.marked = JSON.parse fs.readFileSync(options.marked)
          }
      
          config.sources = options.args.filter({ source ->
            def lang = getLanguage source, config
            if (!lang) {
              log.info "docco: skipped unknown type (${path.basename source})"
            }
            lang
          }).sort()
      
          config
        }
      
        def languages = JSON.parse fs.readFileSync(path.join(__dirname, 'resources', 'languages.json'))
      
        def buildMatchers(languages) {
          languages.each { ext, l ->
            l.commentMatcher = ~/^\s*${l.symbol}\s?/
            l.commentFilter = $/(^#![/]|^\s*#\${'{'})/$
          }
          languages
        }
      
        def getLanguage(source, config) {
          def ext  = config.extension ?: path.extname(source) ?: path.basename(source)
          def lang = config.languages?[ext] ?: languages[ext]
          if (lang && lang.name == 'markdown') {
            def codeExt  = path.extname(path.basename(source, ext))
            def codeLang = config.languages?[codeExt] ?: languages[codeExt]
            if (codeExt && codeLang) {
              lang = _.extend([:], codeLang, [literate: true])
            }
          }
          lang
        }
      
        def version = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'))).version
      
        def run(args = args) {
          def c = defaults
          commander.version(version)
            .usage('groovy docco.gy [options] files')
            .option('-L, --languages [file]', 'use a custom languages.json', _.compose(JSON.&parse, fs.&readFileSync))
            .option('-l, --layout [name]',    'choose a layout (parallel, linear or classic)', c.layout)
            .option('-o, --output [path]',    'output to a given folder', c.output)
            .option('-c, --css [file]',       'use a custom css file', c.css)
            .option('-t, --template [file]',  'use a custom .jst template', c.template)
            .option('-e, --extension [ext]',  'assume a file extension for all inputs', c.extension)
            .option('-m, --marked [file]',    'use custom marked options', c.marked)
            .parse(args)
          if (commander.args.length) {
            document commander
          } else {
            commander.usage()
          }
        }
    
        def args
      
        Docco(Map context) {
          commander._ = _
          fs.path     = path
          fs.tasks    = context.tasks
          args        = context.args
          languages   = buildMatchers languages
        }
      }
    
      DoccoMain(Binding context) {
        super(context)
      }
    }
