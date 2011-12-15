var JSUtils = new (
  function () {
    var jquery_selector_chars = "][#;&,.+*~':\"!^$()=>|/";

    var jquery_escape_selector_data = [];
    for (var i = 0, len = jquery_selector_chars.length; i < len; i++) {
      jquery_escape_selector_data.push([new RegExp("\\" + jquery_selector_chars[i], "g"),
                                        "\\" + jquery_selector_chars[i]]);
    }

    var string_escaper = function (data) {
      return function (str) {
        for (var i = 0, len = data.length; i < len; i++) {
          str = String.prototype.replace.apply(str, data[i]);
        }

        return str;
      };
    };

    var html_escape_data = [[new RegExp("&", "g"), "&amp;"],
                            [new RegExp("<", "g"), "&lt;"],
                            [new RegExp(">", "g"), "&gt;"],
                            [new RegExp('"', "g"), "&quot;"]];

    var single_quote_escape_data = [[new RegExp("'", "g"), "\\'"]];


    this.escape_html = string_escaper(html_escape_data);
    this.escape_jquery_selector = function(str) {
      str = str.replace(/([\]\[\#\;\&\,\.\+\*\~\'\:\"\!\^\$\(\)\=\>\|\/])/g, '\\$1');
      return str;
    };
    this.escape_single_quote = string_escaper(single_quote_escape_data);

    this.isArray = function (obj) {
      return typeof obj == 'object' && obj !== null && typeof obj.length == 'number';
    };

    this.translate_attr = function (attr) {
      if (attr == 'className') {
        return 'class';
      }
      return attr;
    };


    this.template = function(temp) {
      var output = [];

      switch (typeof temp) {
      case 'object':
        if (this.isArray(temp)) {
          output.push("\n<" + temp[0]);
          var next = 1;
          if (temp[1] !== null && typeof temp[1] == 'object' && !this.isArray(temp[1])) {
            next = 2;
            for (var key in temp[1]) {
              output.push(" " + this.translate_attr(key) + "=\"" +
                          this.escape_html(temp[1][key]) + "\"" );
            }
          }

          output.push(">");
          for (var i = next, len = temp.length; i < len; i++) {
            if (temp[i] !== undefined && temp[i] !== null) {
              output = output.concat(this.template(temp[i]));
            }
          }

          output.push("</" + temp[0] + ">");
        } else if (temp instanceof this.UnquotedString) {
          output.push(temp.str);
        } else {
          throw "Illegal operation" + temp;
        }
        break;
      case 'number':
      case 'string':
        output.push(this.escape_html(temp));
        break;

      default:
        throw "Unknown object type" + typeof temp;
        break;
      }

      return output;
    };


    this.generate_html = function (temp) {
      return this.template(temp).join("");
    };

    this.UnquotedString = function (str) {
      this.str = str;
    };


    this.serialize = function (elem) {
      if (elem instanceof this.UnquotedString) {
        return elem.str;
      } else if (elem === undefined) {
        return "undefined";
      } else if (elem === null) {
        return "null";
      } else if (this.isArray(elem)) {
        return this.serialize_array(elem);
      } else if (typeof elem == 'object') {
        return this.serialize_object(elem);
      } else if (typeof elem == 'string') {
        return "'" + this.escape_single_quote(elem) + "'";
      } else if (typeof elem == 'number') {
        return elem;
      } else {
        throw "Unknown type: " + typeof(elem) + " of object: " + elem + " in seralize";
      }
    };

    this.serialize_object = function(obj) {
      var elems = [];
      for (var key in obj) {
        elems.push(this.serialize(key) + ":" + this.serialize(obj[key]));
      }
      return "{" + elems.join(",") + "}";
    };

    this.serialize_array = function (array) {
      var elems = [];
      for (var i = 0, len = array.length; i< len; i++) {
        elems.push(this.serialize(array[i]));
      }

      return "[" + elems.join(",") + "]";
    };

    this.handler_call = function(func_name) {
      var arglist = [];
      for (var i = 1, len = arguments.length; i < len; i++) {
        arglist.push(JSUtils.serialize(arguments[i]));
      }
      var call = func_name + "(" + arglist.join(",") + ")";
      return call;
    };

    var month_lang = {
      da: ['Januar', 'Februar', 'Marts', 'April', 'Maj', 'Juni',
           'Juli', 'August', 'September', 'Oktober', 'November', 'December'],
      en: ['January', 'February', 'March', 'April', 'May', 'June',
           'July', 'August', 'September', 'October', 'November', 'December']
    };

    this.print_date = function (date, lang) {
      var months = month_lang[lang];
      return [date.getDate() + ".", months[date.getMonth() - 1], date.getFullYear()].join(" ");
    };
  })();

