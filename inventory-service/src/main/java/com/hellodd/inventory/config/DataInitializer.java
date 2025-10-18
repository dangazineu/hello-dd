package com.hellodd.inventory.config;

import com.hellodd.inventory.model.Product;
import com.hellodd.inventory.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.List;

/**
 * Initialize sample data for the inventory service.
 * This runs on application startup and populates the H2 database with test data.
 */
@Configuration
@RequiredArgsConstructor
@Slf4j
public class DataInitializer {

    @Bean
    CommandLineRunner initDatabase(ProductRepository repository) {
        return args -> {
            // Clear existing data
            repository.deleteAll();

            // Create sample products
            List<Product> products = Arrays.asList(
                createProduct("LAPTOP-001", "ThinkPad X1 Carbon",
                    "High-performance business laptop with 14-inch display",
                    50, new BigDecimal("1299.99")),

                createProduct("PHONE-001", "iPhone 15 Pro",
                    "Latest iPhone with advanced camera system",
                    100, new BigDecimal("999.99")),

                createProduct("BOOK-001", "Clean Code",
                    "A Handbook of Agile Software Craftsmanship by Robert C. Martin",
                    200, new BigDecimal("45.99")),

                createProduct("CHAIR-001", "Herman Miller Aeron",
                    "Ergonomic office chair with lumbar support",
                    25, new BigDecimal("1395.00")),

                createProduct("MONITOR-001", "Dell UltraSharp 27\"",
                    "4K USB-C Hub Monitor - U2723DE",
                    75, new BigDecimal("599.99")),

                createProduct("KEYBOARD-001", "Keychron K2",
                    "Wireless Mechanical Keyboard",
                    150, new BigDecimal("89.99")),

                createProduct("MOUSE-001", "Logitech MX Master 3S",
                    "Advanced Wireless Mouse",
                    120, new BigDecimal("99.99")),

                createProduct("HEADPHONES-001", "Sony WH-1000XM5",
                    "Noise Cancelling Wireless Headphones",
                    80, new BigDecimal("399.99")),

                createProduct("DESK-001", "Standing Desk Pro",
                    "Electric Height Adjustable Standing Desk",
                    15, new BigDecimal("699.99")),

                createProduct("WEBCAM-001", "Logitech Brio 4K",
                    "Ultra HD Webcam for Video Conferencing",
                    60, new BigDecimal("199.99")),

                // Some low stock items for testing
                createProduct("CABLE-001", "USB-C Cable 2m",
                    "High-speed charging and data cable",
                    5, new BigDecimal("19.99")),

                createProduct("ADAPTER-001", "USB-C Hub",
                    "7-in-1 USB-C Hub with HDMI",
                    3, new BigDecimal("49.99")),

                // Out of stock item for testing
                createProduct("GPU-001", "NVIDIA RTX 4090",
                    "High-end graphics card",
                    0, new BigDecimal("1599.99"))
            );

            // Save all products
            List<Product> savedProducts = repository.saveAll(products);

            log.info("Initialized database with {} products", savedProducts.size());

            // Log some statistics
            long inStockCount = savedProducts.stream()
                .filter(Product::isInStock)
                .count();
            long outOfStockCount = savedProducts.size() - inStockCount;

            log.info("Products in stock: {}, Out of stock: {}",
                inStockCount, outOfStockCount);
        };
    }

    private Product createProduct(String sku, String name, String description,
                                 Integer stockLevel, BigDecimal price) {
        Product product = new Product();
        product.setSku(sku);
        product.setName(name);
        product.setDescription(description);
        product.setStockLevel(stockLevel);
        product.setPrice(price);
        product.setReservedStock(0);
        product.setActive(true);
        return product;
    }
}