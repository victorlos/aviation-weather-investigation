{% macro max_iff(condition) %}
    max(iff( ELEMENT = '{{ condition }}', DATA_VALUE / 10, null))
{% endmacro %}