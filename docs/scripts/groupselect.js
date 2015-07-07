var Obvius = Obvius || {}
Obvius.GroupSelect = Obvius.GroupSelect || {};
(function(w, $) {
    
    function merge_to_select(select, options) {
        if (options.length) {
            select.find("option").each(function() {
                var txt = $(this).text().trim().toLowerCase();
                while (options.length &&
                       txt >= options[0].text().trim().toLowerCase()) {
                    options.shift().insertBefore($(this));
                }
                return options.length > 0;
            });
            $.each(options, function() {
                $(select).append($(this));
            });
        }
    }

    function filter_select(select, match) {
        match = match.toLowerCase();
        select.find("option").each(function() {
            var $option = $(this),
                $parent = $option.parent(),
                text = $option.text().trim().toLowerCase(),
                matches = (text.indexOf(match) == -1);
            if (matches) {
                // Wrap in a hidden span element
                if ($parent.prop("tagName").toLowerCase() != "span") {
                    $option.wrap("<span>").parent().hide();
                    $option.removeAttr("selected");
                }
            } else {
                if ($parent.prop("tagName").toLowerCase() == "span") {
                    $option.insertBefore($parent);
                    $parent.remove();
                }
            }
        });
    }
    
    $.extend(Obvius.GroupSelect, {
        'init': function(id) {
            var addButton = $('#' + id + '-add'),
                removeButton = $('#' + id + '-remove'),
                resultSelect = $('#' + id),
                chosenSelect = $('#' + id + '-chosen'),
                availableSelect = $('#' + id + '-available'),
                chosenFilter = $('#' + id + '-chosen-filter'),
                availableFilter = $('#' + id + '-available-filter');
            
            addButton.on('click', function() {
                var options = [];
                availableSelect.find("option:selected").each(
                    function() {
                        options.push($(this));
                        resultSelect.append(
                            $('<option />').attr(
                                "value", $(this).attr("value")
                            ).attr(
                                "selected", "selected"
                            )
                        );
                    }
                );
                merge_to_select(chosenSelect, options);
                chosenFilter.trigger("keyup");
            });
            
            removeButton.on('click', function() {
                var options = [];
                var removeValues = {};
                chosenSelect.find("option:selected").each(
                    function() {
                        options.push($(this));
                        removeValues[$(this).val()] = true
                    }
                );
                merge_to_select(availableSelect, options);
                resultSelect.find("option").each(function() {
                    if (removeValues[$(this).val()]) {
                        $(this).remove();
                    }
                });
                availableFilter.trigger("keyup");
            });
            
            chosenFilter.on("keyup", function() {
                filter_select(chosenSelect, $(this).val());
            });

            availableFilter.on("keyup", function() {
                filter_select(availableSelect, $(this).val());
            });
        }
    });
})(window, jQuery);