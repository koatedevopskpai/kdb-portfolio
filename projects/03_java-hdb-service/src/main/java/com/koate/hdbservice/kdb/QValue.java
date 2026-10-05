package com.koate.hdbservice.kdb;

import com.kx.c;
import java.lang.reflect.Array;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Converts deserialized q values (as produced by the KX Java client) into plain Java
 * types that Jackson can serialize to JSON.
 *
 * <ul>
 *   <li>a q table ({@link c.Flip}) -&gt; a list of row maps</li>
 *   <li>a q vector (any Java array) -&gt; a list</li>
 *   <li>a q dictionary ({@link c.Dict}) -&gt; a map (or, for keyed tables, the value rows)</li>
 *   <li>atoms -&gt; their Java value; temporal types ({@code c.Timespan}, ...) -&gt; a string</li>
 * </ul>
 */
public final class QValue {

    private QValue() {
    }

    public static Object toJson(Object q) {
        if (q == null) {
            return null;
        }
        if (q instanceof c.Flip flip) {
            return flipToRows(flip);
        }

        Class<?> clazz = q.getClass();
        if (clazz.isArray()) {
            if (q instanceof char[] chars) {
                return new String(chars); // a q char vector is a string
            }
            int n = Array.getLength(q);
            List<Object> out = new ArrayList<>(n);
            for (int i = 0; i < n; i++) {
                out.add(toJson(Array.get(q, i)));
            }
            return out;
        }

        if (q instanceof c.Dict dict) {
            return dictToValue(dict);
        }

        if (q instanceof String || q instanceof Number || q instanceof Boolean) {
            return q;
        }
        if (q instanceof Character ch) {
            return ch.toString();
        }
        // temporal types (c.Timespan, c.Month, c.Minute, c.Second, ...) render via toString
        return q.toString();
    }

    private static List<Map<String, Object>> flipToRows(c.Flip flip) {
        int rows = flip.y.length == 0 ? 0 : Array.getLength(flip.y[0]);
        List<Map<String, Object>> out = new ArrayList<>(rows);
        for (int i = 0; i < rows; i++) {
            Map<String, Object> row = new LinkedHashMap<>();
            for (int j = 0; j < flip.x.length; j++) {
                row.put(flip.x[j], columnValue(flip.y[j], i));
            }
            out.add(row);
        }
        return out;
    }

    private static Object columnValue(Object column, int index) {
        if (column == null) {
            return null;
        }
        if (column.getClass().isArray()) {
            return toJson(Array.get(column, index));
        }
        return toJson(column);
    }

    private static Object dictToValue(c.Dict dict) {
        // a keyed table arrives as a dict of (Flip keys, Flip values): return the rows
        if (dict.x instanceof c.Flip && dict.y instanceof c.Flip) {
            return flipToRows((c.Flip) dict.y);
        }
        Map<Object, Object> map = new LinkedHashMap<>();
        int n = dict.x != null && dict.x.getClass().isArray() ? Array.getLength(dict.x) : 0;
        for (int i = 0; i < n; i++) {
            map.put(toJson(Array.get(dict.x, i)), toJson(Array.get(dict.y, i)));
        }
        return map;
    }
}
