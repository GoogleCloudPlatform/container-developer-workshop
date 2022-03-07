package com.example;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;

@RestController
public class HelloController {

    @Value("${target:local}")
    String target;

    @GetMapping("/") 
    public String hello()
    {
        return String.format("Hello from your %s environment!", target);
    }
}
