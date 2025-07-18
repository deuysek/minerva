/*jslint onevar: false, plusplus: false */
/*

 JS Beautifier
---------------


  Written by Einar Lielmanis, <einars@gmail.com>
      http://jsbeautifier.org/

  Originally converted to javascript by Vital, <vital76@gmail.com>

  You are free to use this in any way you want, in case you find this useful or working for you.

  Usage:
    js_beautify(js_source_text);
    js_beautify(js_source_text, options);

  The options are:
    indent_size (default 4) — indentation size,
    indent_char (default space) — character to indent with,
    preserve_newlines (default true) — whether existing line breaks should be preserved,
	preserve_max_newlines (default unlimited) - maximum number of line breaks to be preserved in one chunk,
    indent_level (default 0)  — initial indentation level, you probably won't need this ever,

    space_after_anon_function (default false) — if true, then space is added between "function ()"
            (jslint is happy about this); if false, then the common "function()" output is used.
	braces_on_own_line (default false) - ANSI / Allman brace style, each opening/closing brace gets its own line.

    e.g

    js_beautify(js_source_text, {indent_size: 1, indent_char: '\t'});


*/

package com.coursevector.data {

	public class JSFormatter {
		
		protected var output:Array;
		protected var input:String;
		protected var token_text:String;
		protected var last_type:String;
		protected var last_text:String;
		protected var last_last_text:String;
		protected var last_word:String;
		protected var flags:Object;
		protected var flag_store:Array;
		protected var indent_string:String;
		
		protected var whitespace:Array;
		protected var wordchar:Array;
		protected var punct:Array;
		protected var parser_pos:int;
		protected var line_starters:Array;
		protected var digits:Array;
		
		protected var prefix:String;
		protected var token_type:String;
		protected var do_block_just_closed:Boolean;
		
		protected var indent_level:int;
		protected var wanted_newline:Boolean;
		protected var just_added_newline:Boolean;
		protected var n_newlines:int;
		protected var input_length:int;
		
		protected var opt_indent_size:int;//缩进长度
		protected var opt_braces_on_own_line:Boolean;//大括号换行
		protected var opt_indent_char:String;//缩进字符
		protected var opt_preserve_newlines:Boolean;//保留空行
		protected var opt_max_preserve_newlines:int;//最大空行数量
		protected var opt_indent_level:int;//缩进等级(未知)
		protected var opt_space_after_anon_function:Boolean;//空函数后方插入空格
		protected var opt_keep_array_indentation:Boolean;//保留数组缩进
		
		public function JSFormatter() { }
		
		public function format(js_source_text:String, options:Object = null):String {
			options               = options || {};
			opt_braces_on_own_line = options.braces_on_own_line ? options.braces_on_own_line : false;
			opt_indent_size       = options.indent_size || 4;
			opt_indent_char       = options.indent_char || ' ';
			opt_preserve_newlines =	options.hasOwnProperty("preserve_newlines") ? options.preserve_newlines : true;
			opt_max_preserve_newlines = options.hasOwnProperty("max_preserve_newlines") ? options.max_preserve_newlines : 999;
			indent_level      	  = options.indent_level || 0; // starting indentation
			opt_space_after_anon_function = options.hasOwnProperty("space_after_anon_function") ? options.space_after_anon_function : false;
			opt_keep_array_indentation = options.hasOwnProperty("keep_array_indentation") ? options.keep_array_indentation : false;
			
			just_added_newline = false;
			
			// cache the source's length.
    		input_length = js_source_text.length;
			
			//----------------------------------
			
			indent_string = '';
			while (opt_indent_size > 0) {
				indent_string += opt_indent_char;
				opt_indent_size -= 1;
			}
			
			input = js_source_text.replace(/\n\r/g,"\n");
			
			last_word = ''; // last 'TK_WORD' passed
			last_type = 'TK_START_EXPR'; // last token type
			last_text = ''; // last token text
			last_last_text = ''; // pre-last token text
			output = [];
			
			do_block_just_closed = false;
			
			whitespace = "\n\r\t ".split('');
			wordchar = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$'.split('');
			digits = '0123456789'.split('');
			
			punct = '+ - * / % & ++ -- = += -= *= /= %= == === != !== > < >= <= >> << >>> >>>= >>= <<= && &= | || ! !! , : ? ^ ^= |= ::'.split(' ');
			
			// words which should always start on new line.
			line_starters = 'continue,try,throw,return,var,if,switch,case,default,for,while,break,function'.split(',');
			
			// states showing if we are currently in expression (i.e. "if" case) - 'EXPRESSION', or in usual block (like, procedure), 'BLOCK'.
			// some formatting depends on that.
			flag_store = [];
			set_mode('BLOCK');
			
			parser_pos = 0;
			while (true) {
				var t:Array = get_next_token(parser_pos);
				
				token_text = t[0];
				token_type = t[1];
				if (token_type === 'TK_EOF') break;
				
				switch (token_type) {
					case 'TK_START_EXPR':
						if (token_text === '[') {
							if (last_type === 'TK_WORD' || last_text === ')') {
								// this is array index specifier, break immediately
								// a[x], fn()[x]
								if (in_array(last_text, line_starters)) {
									print_single_space();
								}
								set_mode('(EXPRESSION)');
								print_token();
								break;
							}
							
							if (flags.mode === '[EXPRESSION]' || flags.mode === '[INDENTED-EXPRESSION]') {
								if (last_last_text === ']' && last_text === ',') {
									// ], [ goes to new line
									if (flags.mode === '[EXPRESSION]') {
										flags.mode = '[INDENTED-EXPRESSION]';
										if (!opt_keep_array_indentation) {
											indent();
										}
									}
									set_mode('[EXPRESSION]');
									if (!opt_keep_array_indentation) {
										print_newline();
									}
								} else if (last_text === '[') {
									if (flags.mode === '[EXPRESSION]') {
										flags.mode = '[INDENTED-EXPRESSION]';
										if (!opt_keep_array_indentation) {
											indent();
										}
									}
									set_mode('[EXPRESSION]');
									
									if (!opt_keep_array_indentation) {
										print_newline();
									}
								} else {
									set_mode('[EXPRESSION]');
								}
							} else {
								set_mode('[EXPRESSION]');
							}
						} else {
							set_mode('(EXPRESSION)');
						}
						
						if (last_text === ';' || last_type === 'TK_START_BLOCK') {
							print_newline();
						} else if (last_type === 'TK_END_EXPR' || last_type === 'TK_START_EXPR' || last_type === 'TK_END_BLOCK' || last_text === '.') {
							// do nothing on (( and )( and ][ and ]( and .(
						} else if (last_type !== 'TK_WORD' && last_type !== 'TK_OPERATOR') {
							print_single_space();
						} else if (last_word === 'function') {
							// function() vs function ()
							if (opt_space_after_anon_function) {
								print_single_space();
							}
						} else if (in_array(last_text, line_starters) || last_text === 'catch') {
							print_single_space();
						}
						print_token();
						break;
					case 'TK_END_EXPR':
						if (token_text === ']') {
							if (opt_keep_array_indentation) {
								if (last_text === '}') {
									// trim_output();
									// print_newline(true);
									remove_indent();
									print_token();
									restore_mode();
									break;
								}
							} else {
								if (flags.mode === '[INDENTED-EXPRESSION]') {
									if (last_text === ']') {
										restore_mode();
										print_newline();
										print_token();
										break;
									}
								}
							}
						}
						restore_mode();
						print_token();
						break;
					case 'TK_START_BLOCK':
						if (last_word === 'do') {
							set_mode('DO_BLOCK');
						} else {
							set_mode('BLOCK');
						}
						if (opt_braces_on_own_line) {
							if (last_type !== 'TK_OPERATOR') {
								if (last_text == 'return') {
									print_single_space();
								} else {
									print_newline(true);
								}
							}
							print_token();
							indent();
						} else {
							if (last_type !== 'TK_OPERATOR' && last_type !== 'TK_START_EXPR') {
								if (last_type === 'TK_START_BLOCK') {
									print_newline();
								} else {
									print_single_space();
								}
							} else {
								// if TK_OPERATOR or TK_START_EXPR
								if (is_array(flags.previous_mode) && last_text === ',') {
									if (last_last_text === '}') {
										// }, { in array context
										print_single_space();
									} else {
										print_newline(); // [a, b, c, {
									}
								}
							}
							indent();
							print_token();
						}
						break;
					case 'TK_END_BLOCK':
						restore_mode();
						if (opt_braces_on_own_line) {
							print_newline();
							print_token();
						} else {
							if (last_type === 'TK_START_BLOCK') {
								// nothing
								if (just_added_newline) {
									remove_indent();
								} else {
									// {}
									trim_output();
								}
							} else {
								if (is_array(flags.mode) && opt_keep_array_indentation) {
									// we REALLY need a newline here, but newliner would skip that
									opt_keep_array_indentation = false;
									print_newline();
									opt_keep_array_indentation = true;
									
								} else {
									print_newline();
								}
							}
							print_token();
						}
						break;
					case 'TK_WORD':
						// no, it's not you. even I have problems understanding how this works
						// and what does what.
						if (do_block_just_closed) {
							// do {} ## while ()
							print_single_space();
							print_token();
							print_single_space();
							do_block_just_closed = false;
							break;
						}
						
						if (token_text === 'function') {
							if ((just_added_newline || last_text === ';') && last_text !== '{') {
								// make sure there is a nice clean space of at least one blank line
								// before a new function definition
								n_newlines = just_added_newline ? n_newlines : 0;
								if ( ! opt_preserve_newlines) {
									n_newlines = 1;
								}
								
								for (var i:int = 0; i < 2 - n_newlines; i++) {
									print_newline(false);
								}
							}
						}
						if (token_text === 'case' || token_text === 'default') {
							if (last_text === ':') {
								// switch cases following one another
								remove_indent();
							} else {
								// case statement starts in the same line where switch
								flags.indentation_level--;
								print_newline();
								flags.indentation_level++;
							}
							print_token();
							flags.in_case = true;
							break;
						}
						
						prefix = 'NONE';
						
						if (last_type === 'TK_END_BLOCK') {
							if (!in_array(token_text.toLowerCase(), ['else', 'catch', 'finally'])) {
								prefix = 'NEWLINE';
							} else {
								if (opt_braces_on_own_line) {
									prefix = 'NEWLINE';
								} else {
									prefix = 'SPACE';
									print_single_space();
								}
							}
						} else if (last_type === 'TK_SEMICOLON' && (flags.mode === 'BLOCK' || flags.mode === 'DO_BLOCK')) {
							prefix = 'NEWLINE';
						} else if (last_type === 'TK_SEMICOLON' && is_expression(flags.mode)) {
							prefix = 'SPACE';
						} else if (last_type === 'TK_STRING') {
							prefix = 'NEWLINE';
						} else if (last_type === 'TK_WORD') {
							prefix = 'SPACE';
						} else if (last_type === 'TK_START_BLOCK') {
							prefix = 'NEWLINE';
						} else if (last_type === 'TK_END_EXPR') {
							print_single_space();
							prefix = 'NEWLINE';
						}
						
						if (flags.if_line && last_type === 'TK_END_EXPR') {
							flags.if_line = false;
						}
						if (in_array(token_text.toLowerCase(), ['else', 'catch', 'finally'])) {
							if (last_type !== 'TK_END_BLOCK' || opt_braces_on_own_line) {
								print_newline();
							} else {
								trim_output(true);
								print_single_space();
							}
						} else if (in_array(token_text, line_starters) || prefix === 'NEWLINE') {
							if ((last_type === 'TK_START_EXPR' || last_text === '=' || last_text === ',') && token_text === 'function') {
								// no need to force newline on 'function': (function
								// DONOTHING
							} else if (last_text === 'return' || last_text === 'throw') {
								// no newline between 'return nnn'
								print_single_space();
							} else if (last_type !== 'TK_END_EXPR') {
								if ((last_type !== 'TK_START_EXPR' || token_text !== 'var') && last_text !== ':') {
									// no need to force newline on 'var': for (var x = 0...)
									if (token_text === 'if' && last_word === 'else' && last_text !== '{') {
										// no newline for } else if {
										print_single_space();
									} else {
										print_newline();
									}
								}
							} else {
								if (in_array(token_text, line_starters) && last_text !== ')') {
									print_newline();
								}
							}
						} else if (is_array(flags.mode) && last_text === ',' && last_last_text === '}') {
							print_newline(); // }, in lists get a newline treatment
						} else if (prefix === 'SPACE') {
							print_single_space();
						}
						print_token();
						last_word = token_text;
						
						if (token_text === 'var') {
							flags.var_line = true;
							flags.var_line_reindented = false;
							flags.var_line_tainted = false;
						}
						
						if (token_text === 'if') {
							flags.if_line = true;
						}
						if (token_text === 'else') {
							flags.if_line = false;
						}
						
						break;
					case 'TK_SEMICOLON':
						print_token();
						flags.var_line = false;
						flags.var_line_reindented = false;
						break;
					case 'TK_STRING':
						if (last_type === 'TK_START_BLOCK' || last_type === 'TK_END_BLOCK' || last_type === 'TK_SEMICOLON') {
							print_newline();
						} else if (last_type === 'TK_WORD') {
							print_single_space();
						}
						print_token();
						break;
					case 'TK_EQUALS':
					            if (flags.var_line) {
					                // just got an '=' in a var-line, different formatting/line-breaking, etc will now be done
					                flags.var_line_tainted = true;
					            }
					            print_single_space();
					            print_token();
					            print_single_space();
					            break;
					case 'TK_OPERATOR':
						var space_before:Boolean = true;
						var space_after:Boolean = true;
						if (flags.var_line && token_text === ',' && (is_expression(flags.mode))) {
							// do not break on comma, for(var a = 1, b = 2)
							flags.var_line_tainted = false;
						}
						
						if (flags.var_line) {
							if (token_text === ',') {
								if (flags.var_line_tainted) {
									print_token();
									flags.var_line_reindented = true;
									flags.var_line_tainted = false;
									print_newline();
									break;
								} else {
									flags.var_line_tainted = false;
								}
							// } else if (token_text === ':') {
                    						// hmm, when does this happen? tests don't catch this
                    						// flags.var_line = false;
							}
						}
						
						if (last_text === 'return' || last_text === 'throw') {
							// "return" had a special handling in TK_WORD. Now we need to return the favor
							print_single_space();
							print_token();
							break;
						}
						
						if (token_text === ':' && flags.in_case) {
							print_token(); // colon really asks for separate treatment
							print_newline();
							flags.in_case = false; 
							break;
						}
						
						if (token_text === '::') {
							// no spaces around exotic namespacing syntax operator
							print_token();
							break;
						}
						
						if (token_text === ',') {
							if (flags.var_line) {
								if (flags.var_line_tainted) {
									print_token();
									print_newline();
									flags.var_line_tainted = false;
								} else {
									print_token();
									print_single_space();
								}
							} else if (last_type === 'TK_END_BLOCK' && flags.mode !== "(EXPRESSION)") {
								print_token();
								if (flags.mode === 'OBJECT' && last_text === '}') {
									print_newline();
								} else {
									print_single_space();
								}
							} else {
								if (flags.mode === 'OBJECT') {
									print_token();
									print_newline();
								} else {
									// EXPR or DO_BLOCK
									print_token();
									print_single_space();
								}
							}
							break;
						// } else if (in_array(token_text, ['--', '++', '!']) || (in_array(token_text, ['-', '+']) && (in_array(last_type, ['TK_START_BLOCK', 'TK_START_EXPR', 'TK_EQUALS']) || in_array(last_text, line_starters) || in_array(last_text, ['==', '!=', '+=', '-=', '*=', '/=', '+', '-'])))) {
						} else if (in_array(token_text, ['--', '++', '!']) || (in_array(token_text, ['-', '+']) && (in_array(last_type, ['TK_START_BLOCK', 'TK_START_EXPR', 'TK_EQUALS', 'TK_OPERATOR']) || in_array(last_text, line_starters)))) {
							// unary operators (and binary +/- pretending to be unary) special cases
								
									space_before = false;
									space_after = false;
									
								if (last_text === ';' && is_expression(flags.mode)) {
									// for (;; ++i)
									//        ^^^
									space_before = true;
								}
								if (last_type === 'TK_WORD' && in_array(last_text, line_starters)) {
									space_before = true;
								}
								
								if (flags.mode === 'BLOCK' && (last_text === '{' || last_text === ';')) {
									// { foo; --i }
									// foo(); --bar;
									print_newline();
								}
						} else if (token_text === '.') {
							// decimal digits or object.property
							space_before = false;
						} else if (token_text === ':') {
							if (!is_ternary_op()) {
								flags.mode = 'OBJECT';
								space_before = false;
							}
						}
						if (space_before) {
							print_single_space();
						}
						
						print_token();
						
						if (space_after) {
							print_single_space();
						}
						
						if (token_text === '!') {
                                                	// flags.eat_next_space = true;
						}
						
						break;
					case 'TK_BLOCK_COMMENT':
						var lines:Array = token_text.split(/\x0a|\x0d\x0a/);
						
						if (/^\/\*\*/.test(token_text)) {
							// javadoc: reformat and reindent
							print_newline();
							output.push(lines[0]);
							for (i = 1; i < lines.length; i++) {
								print_newline();
								output.push(' ');
								output.push(trim(lines[i]));
							}
							
						} else {
							
							// simple block comment: leave intact
							if (lines.length > 1) {
								// multiline comment block starts with a new line
								print_newline();
								trim_output();
							} else {
								// single-line /* comment */ stays where it is
								print_single_space();
								
							}
							
							for (i = 0; i < lines.length; i++) {
								output.push(lines[i]);
								output.push('\n');
							}
							
						}
						print_newline();
						break;
					case 'TK_INLINE_COMMENT':
						
						print_single_space();
						print_token();
						if (is_expression(flags.mode)) {
							print_single_space();
						} else {
							print_newline();
						}
						break;
					case 'TK_COMMENT':
						// print_newline();
						if (wanted_newline) {
			                print_newline();
			            } else {
							print_single_space();
			            }
						print_token();
						print_newline();
						break;
					case 'TK_UNKNOWN':
						if (last_text === 'return' || last_text === 'throw') {
							print_single_space();
						}
						print_token();
						break;
				}
				
				last_last_text = last_text;
				last_type = token_type;
				last_text = token_text;
			}
			
			return output.join('').replace(/[\n ]+$/, '');
		}
		
		private function trim_output(eat_newlines:Boolean = false):void {
			eat_newlines = typeof eat_newlines === 'undefined' ? false : eat_newlines;
			while (output.length && (output[output.length - 1] === ' '
				|| output[output.length - 1] === indent_string
				|| (eat_newlines && (output[output.length - 1] === '\n' || output[output.length - 1] === '\r')))) {
				output.pop();
			}
		}
		
		private function trim(s:String):String {
			return s.replace(/^\s\s*|\s\s*$/, '');
		}
		
		private function print_newline(ignore_repeated:Boolean = true):void {
			flags.eat_next_space = false;
			if (opt_keep_array_indentation && is_array(flags.mode)) return;
			
			ignore_repeated = typeof ignore_repeated === 'undefined' ? true : ignore_repeated;
			
			flags.if_line = false;
			trim_output();
			
			if (!output.length) return; // no newline on start of file
			
			if (output[output.length - 1] !== "\n" || !ignore_repeated) {
				just_added_newline = true;
				output.push("\n");
			}
			
			for (var i:int = 0; i < flags.indentation_level; i += 1) {
				output.push(indent_string);
			}
			if (flags.var_line && flags.var_line_reindented) {
				if (opt_indent_char === ' ') {
					output.push('    '); // var_line always pushes 4 spaces, so that the variables would be one under another
				} else {
					output.push(indent_string); // skip space-stuffing, if indenting with a tab
				}
			}
		}
		
		private function print_single_space():void {
			if (flags.eat_next_space) {
            			flags.eat_next_space = false;
            			return;
        		}
			var last_output:String = ' ';
			if (output.length) last_output = output[output.length - 1];
			if (last_output !== ' ' && last_output !== '\n' && last_output !== indent_string) { // prevent occassional duplicate space
				output.push(' ');
			}
		}
		
		private function print_token():void {
			just_added_newline = false;
			flags.eat_next_space = false;
			output.push(token_text);
		}
		
		private function indent():void {
			flags.indentation_level += 1;
		}
		
		private function remove_indent():void {
			if (output.length && output[output.length - 1] === indent_string) {
				output.pop();
			}
		}
		
		private function set_mode(mode:String):void {
			if (flags) flag_store.push(flags);
			
			flags = {
				previous_mode: flags ? flags.mode : 'BLOCK',
				mode: mode,
				var_line: false,
				var_line_tainted: false,
				var_line_reindented: false,
				in_html_comment: false,
				if_line: false,
				in_case: false,
				eat_next_space: false,
				indentation_baseline: -1,
				indentation_level: (flags ? flags.indentation_level + ((flags.var_line && flags.var_line_reindented) ? 1 : 0) : opt_indent_level)
			};
		}
		
		private function is_array(mode:String):Boolean {
        	return mode === '[EXPRESSION]' || mode === '[INDENTED-EXPRESSION]';
    	}
		
		private function is_expression(mode:String):Boolean {
			return mode === '[EXPRESSION]' || mode === '[INDENTED-EXPRESSION]' || mode === '(EXPRESSION)';
		}
		
		private function restore_mode():void {
			do_block_just_closed = flags.mode === 'DO_BLOCK';
			if (flag_store.length > 0) flags = flag_store.pop();
		}
		
		private function in_array(what:String, arr:Array):Boolean {
			var l:int = arr.length;
			for (var i:int = 0; i < l; ++i) {
				if (arr[i] === what) return true;
			}
			return false;
		}
		
		// Walk backwards from the colon to find a '?' (colon is part of a ternary op)
		// or a '{' (colon is part of a class literal).  Along the way, keep track of
		// the blocks and expressions we pass so we only trigger on those chars in our
		// own level, and keep track of the colons so we only trigger on the matching '?'.
		private function is_ternary_op():Boolean {
			var level:int = 0, colon_count:int = 0;
			for (var i:int = output.length - 1; i >= 0; i--) {
				switch (output[i]) {
					case ':':
						if (level === 0) colon_count++;
						break;
					case '?':
						if (level === 0) {
							if (colon_count === 0) {
								return true;
							} else {
								colon_count--;
							}
						} 
						break;
					case '{':
						if (level === 0) return false;
						level--;
						break;
					case '(':
					case '[':
						level--;
						break;
					case ')':
					case ']':
					case '}':
						level++;
						break;
				}
			}
			return false;
		}
		
		private function get_next_token(pos:int = 0):Array {
			n_newlines = 0;
			
			if (parser_pos >= input_length) return ['', 'TK_EOF'];
			
			wanted_newline = false;
			
			var i:int;
			var c:String = input.charAt(parser_pos);
			parser_pos += 1;
			
			var keep_whitespace:Boolean = opt_keep_array_indentation && is_array(flags.mode);
			
			if (keep_whitespace) {
			
			    //
			    // slight mess to allow nice preservation of array indentation and reindent that correctly
			    // first time when we get to the arrays:
			    // var a = [
			    // ....'something'
			    // we make note of whitespace_count = 4 into flags.indentation_baseline
			    // so we know that 4 whitespaces in original source match indent_level of reindented source
			    //
			    // and afterwards, when we get to
			    //    'something,
			    // .......'something else'
			    // we know that this should be indented to indent_level + (7 - indentation_baseline) spaces
			    //
			    var whitespace_count:int = 0;
			
				while (in_array(c, whitespace)) {
					if (c === "\n") {
	                    trim_output();
	                    output.push("\n");
	                    just_added_newline = true;
	                    whitespace_count = 0;
	                } else {
	                    if (c === '\t') {
	                        whitespace_count += 4;
						} else if (c === '\r') {
							// nothing
	                    } else {
	                        whitespace_count += 1;
	                    }
	                }
					
					if (parser_pos >= input_length) return ['', 'TK_EOF'];
					
					c = input.charAt(parser_pos);
	                parser_pos += 1;
				}
				
				if (flags.indentation_baseline === -1) flags.indentation_baseline = whitespace_count;
	
	            if (just_added_newline) {
	                for (i = 0; i < flags.indentation_level + 1; ++i) {
	                    output.push(indent_string);
	                }
	                if (flags.indentation_baseline !== -1) {
	                    for (i = 0; i < whitespace_count - flags.indentation_baseline; i++) {
	                        output.push(' ');
	                    }
	                }
	            }
			} else {
				
            	while (in_array(c, whitespace)) {	
					//if (c === "\n" || c === "\r") n_newlines += ( (opt_max_preserve_newlines) ? ((n_newlines <= opt_max_preserve_newlines) ? 1: 0): 1 );
					if (c === "\n") n_newlines += ( (opt_max_preserve_newlines) ? ((n_newlines <= opt_max_preserve_newlines) ? 1: 0): 1 );
					
					if (parser_pos >= input_length) return ['', 'TK_EOF'];
					
					c = input.charAt(parser_pos);
					parser_pos += 1;
				}
			
				if (opt_preserve_newlines) {
					if (n_newlines > 1) {
						for (i = 0; i < n_newlines; ++i) {
							print_newline(i === 0);
							just_added_newline = true;
						}
					}
				}
				wanted_newline = n_newlines > 0;
			}
			
			if (in_array(c, wordchar)) {
				if (parser_pos < input_length) {
					while (in_array(input.charAt(parser_pos), wordchar)) {
						c += input.charAt(parser_pos);
						parser_pos += 1;
						if (parser_pos === input_length) break;
					}
				}
				
				// small and surprisingly unugly hack for 1E-10 representation
				if (parser_pos !== input_length && c.match(/^[0-9]+[Ee]$/) && (input.charAt(parser_pos) === '-' || input.charAt(parser_pos) === '+')) {
					var sign:String = input.charAt(parser_pos);
					parser_pos += 1;
					
					var t:Array = get_next_token(parser_pos);
					c += sign + t[0];
					return [c, 'TK_WORD'];
				}
				
				if (c === 'in') return [c, 'TK_OPERATOR']; // hack for 'in' operator
				
				if (wanted_newline && last_type !== 'TK_OPERATOR' && !flags.if_line && (opt_preserve_newlines || last_text !== 'var')) {
					print_newline();
				}
				return [c, 'TK_WORD'];
			}
			
			if (c === '(' || c === '[') return [c, 'TK_START_EXPR'];
			
			if (c === ')' || c === ']') return [c, 'TK_END_EXPR'];
			
			if (c === '{') return [c, 'TK_START_BLOCK'];
			
			if (c === '}') return [c, 'TK_END_BLOCK'];
			
			if (c === ';') return [c, 'TK_SEMICOLON'];
			
			if (c === '/') {
				var comment:String = '';
				// peek for comment /* ... */
				var inline_comment:Boolean = true;
				if (input.charAt(parser_pos) === '*') {
					parser_pos += 1;
					if (parser_pos < input.length) {
						while (!(input.charAt(parser_pos) === '*' && input.charAt(parser_pos + 1) && input.charAt(parser_pos + 1) === '/') && parser_pos < input.length) {
							c = input.charAt(parser_pos);
							comment += c;
							if (c === '\x0d' || c === '\x0a') {
								inline_comment = false;
							}
							parser_pos += 1;
							if (parser_pos >= input.length) {
								break;
							}
						}
					}
					parser_pos += 2;
					if (inline_comment) {
						return ['/*' + comment + '*/', 'TK_INLINE_COMMENT'];
					} else {
						return ['/*' + comment + '*/', 'TK_BLOCK_COMMENT'];
					}
				}
				// peek for comment // ...
				if (input.charAt(parser_pos) === '/') {
					comment = c;
					while (input.charAt(parser_pos) !== '\r' && input.charAt(parser_pos) !== '\n') {
						comment += input.charAt(parser_pos);
						parser_pos += 1;
						if (parser_pos >= input_length) {
							break;
						}
					}
					parser_pos += 1;
					if (wanted_newline) {
						print_newline();
					}
					return [comment, 'TK_COMMENT'];
				}
			}
			
			if (c === "'" || // string
			c === '"' || // string
			(c === '/' &&
				((last_type === 'TK_WORD' && in_array(last_text, ['return', 'do'])) ||
					(last_type === 'TK_COMMENT' || last_type === 'TK_START_EXPR' || last_type === 'TK_START_BLOCK' || last_type === 'TK_END_BLOCK' || last_type === 'TK_OPERATOR' || last_type === 'TK_EQUALS' || last_type === 'TK_EOF' || last_type === 'TK_SEMICOLON')))) { // regexp
				var sep:String = c;
				var esc:Boolean = false;
				var resulting_string:String = c;
				
				if (parser_pos < input_length) {
					if (sep === '/') {
						//
						// handle regexp separately...
						//
						
						var in_char_class:Boolean = false;
						while (esc || in_char_class || input.charAt(parser_pos) !== sep) {
							resulting_string += input.charAt(parser_pos);
							if (!esc) {
								esc = input.charAt(parser_pos) === '\\';
								if (input.charAt(parser_pos) === '[') {
									in_char_class = true;
								} else if (input.charAt(parser_pos) === ']') {
									in_char_class = false;
								}
							} else {
								esc = false;
							}
							parser_pos += 1;
							if (parser_pos >= input_length) {
								// incomplete string/rexp when end-of-file reached. 
								// bail out with what had been received so far.
								return [resulting_string, 'TK_STRING'];
							}
						}
					} else {
						//
						// and handle string also separately
						//
						while (esc || input.charAt(parser_pos) !== sep) {
							resulting_string += input.charAt(parser_pos);
							if (!esc) {
								esc = input.charAt(parser_pos) === '\\';
							} else {
								esc = false;
							}
							parser_pos += 1;
							if (parser_pos >= input_length) {
								// incomplete string/rexp when end-of-file reached. 
								// bail out with what had been received so far.
								return [resulting_string, 'TK_STRING'];
							}
						}
					}
				}
				
				parser_pos += 1;
				
				resulting_string += sep;
				
				if (sep === '/') {
					// regexps may have modifiers /regexp/MOD , so fetch those, too
					while (parser_pos < input_length && in_array(input.charAt(parser_pos), wordchar)) {
						resulting_string += input.charAt(parser_pos);
						parser_pos += 1;
					}
				}
				return [resulting_string, 'TK_STRING'];
			}
			
			if (c === '#') {
				if (output.length === 0 && input.charAt(parser_pos) === '!') {
					// shebang
					resulting_string = c;
					while (parser_pos < input_length && c != '\n') {
						c = input.charAt(parser_pos);
						resulting_string += c;
						parser_pos += 1;
					}
					output.push(trim(resulting_string) + '\n');
					print_newline();
					return get_next_token();
				}
				
				// Spidermonkey-specific sharp variables for circular references
				// https://developer.mozilla.org/En/Sharp_variables_in_JavaScript
				// http://mxr.mozilla.org/mozilla-central/source/js/src/jsscan.cpp around line 1935
				var sharp:String = '#';
				if (parser_pos < input_length && in_array(input.charAt(parser_pos), digits)) {
					do {
						c = input.charAt(parser_pos);
						sharp += c;
						parser_pos += 1;
					} while (parser_pos < input_length && c !== '#' && c !== '=');
					if (c === '#') {
						//
					} else if (input.charAt(parser_pos) === '[' && input.charAt(parser_pos + 1) === ']') {
						sharp += '[]';
						parser_pos += 2;
					} else if (input.charAt(parser_pos) === '{' && input.charAt(parser_pos + 1) === '}') {
						sharp += '{}';
						parser_pos += 2;
					}
					return [sharp, 'TK_WORD'];
				}
			}
			
			if (c === '<' && input.substring(parser_pos - 1, parser_pos + 3) === '<!--') {
				parser_pos += 3;
				flags.in_html_comment = true;
				return ['<!--', 'TK_COMMENT'];
			}
			
			if (c === '-' && flags.in_html_comment && input.substring(parser_pos - 1, parser_pos + 2) === '-->') {
				flags.in_html_comment = false;
				parser_pos += 2;
				if (wanted_newline) {
					print_newline();
				}
				return ['-->', 'TK_COMMENT'];
			}
			
			if (in_array(c, punct)) {
				while (parser_pos < input_length && in_array(c + input.charAt(parser_pos), punct)) {
					c += input.charAt(parser_pos);
					parser_pos += 1;
					if (parser_pos >= input_length) {
						break;
					}
				}
				
				if (c === '=') {
                			return [c, 'TK_EQUALS'];
            			} else {
					return [c, 'TK_OPERATOR'];
				}
			}
			
			return [c, 'TK_UNKNOWN'];
		}
	}
}