package com.koate.hdbservice.kdb;

import static org.assertj.core.api.Assertions.assertThat;

import com.kx.c;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class QValueTest {

    @Test
    @SuppressWarnings("unchecked")
    void convertsTableToRows() {
        c.Flip flip = new c.Flip(
                new String[] {"sym", "price"},
                new Object[] {new String[] {"AAPL", "MSFT"}, new double[] {1.5, 2.5}});

        Object json = QValue.toJson(flip);

        assertThat(json).isInstanceOf(List.class);
        List<Map<String, Object>> rows = (List<Map<String, Object>>) json;
        assertThat(rows).hasSize(2);
        assertThat(rows.get(0)).containsEntry("sym", "AAPL").containsEntry("price", 1.5);
        assertThat(rows.get(1)).containsEntry("sym", "MSFT").containsEntry("price", 2.5);
    }

    @Test
    void convertsVectors() {
        assertThat(QValue.toJson(new long[] {1, 2, 3})).isEqualTo(List.of(1L, 2L, 3L));
        assertThat(QValue.toJson(new double[] {1.0, 2.0})).isEqualTo(List.of(1.0, 2.0));
        assertThat(QValue.toJson(new String[] {"a", "b"})).isEqualTo(List.of("a", "b"));
    }

    @Test
    void convertsAtoms() {
        assertThat(QValue.toJson("hello")).isEqualTo("hello");
        assertThat(QValue.toJson(42L)).isEqualTo(42L);
        assertThat(QValue.toJson(3.14)).isEqualTo(3.14);
        assertThat(QValue.toJson(Boolean.TRUE)).isEqualTo(true);
        assertThat(QValue.toJson('x')).isEqualTo("x");
    }

    @Test
    void convertsQString() {
        assertThat(QValue.toJson(new char[] {'a', 'b', 'c'})).isEqualTo("abc");
    }

    @Test
    void nullIsNull() {
        assertThat(QValue.toJson(null)).isNull();
    }
}
