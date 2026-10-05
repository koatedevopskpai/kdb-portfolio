package com.koate.hdbservice.web;

import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.koate.hdbservice.kdb.KdbException;
import com.koate.hdbservice.kdb.KdbQueryService;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(HdbController.class)
class HdbControllerTest {

    @Autowired
    MockMvc mvc;

    @MockBean
    KdbQueryService queries;

    @Test
    void symbolsReturnsJsonArray() throws Exception {
        when(queries.symbols()).thenReturn(List.of("AAPL", "MSFT"));
        mvc.perform(get("/api/symbols"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0]").value("AAPL"))
                .andExpect(jsonPath("$[1]").value("MSFT"));
    }

    @Test
    void tradesPassesLimit() throws Exception {
        when(queries.trades(eq("MSFT"), anyInt()))
                .thenReturn(List.of(Map.of("price", 100.0, "size", 10)));
        mvc.perform(get("/api/trades/MSFT").param("limit", "3"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].price").value(100.0));
    }

    @Test
    void healthUpWhenKdbReachable() throws Exception {
        when(queries.ping()).thenReturn(true);
        mvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void healthDownWhenKdbUnreachable() throws Exception {
        when(queries.ping()).thenReturn(false);
        mvc.perform(get("/api/health"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.status").value("DOWN"));
    }

    @Test
    void badSymbolReturns400() throws Exception {
        when(queries.statsFor("EVIL")).thenThrow(new IllegalArgumentException("invalid symbol: EVIL"));
        mvc.perform(get("/api/stats/EVIL"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("bad request"));
    }

    @Test
    void kdbFailureReturns503() throws Exception {
        when(queries.allStats()).thenThrow(new KdbException("cannot connect to kdb+"));
        mvc.perform(get("/api/stats"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.error").value("kdb+ unavailable"));
    }
}
